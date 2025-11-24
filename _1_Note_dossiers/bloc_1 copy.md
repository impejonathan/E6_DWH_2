Parfait ! 🎯

**On se concentre sur BLOC 1 & 2 jusqu'à ce que tu me dises de passer au suivant.**

---

# 🔵 **BLOC 1 : ANALYSE & CONCEPTION**

## 📊 **1.1 - ANALYSE DE L'ARCHITECTURE ACTUELLE**

### **Schéma existant (avant Marketplace)**

Ton DWH actuel est un **modèle en étoile simple** avec :

**Dimensions :**
- `dim_customer` : informations clients
- `dim_product` : catalogue produits

**Faits :**
- `fact_order` : commandes passées
- `fact_clickstream` : navigation utilisateurs

**Flux d'alimentation :**
- **Event Hubs** : `orders`, `clickstream` (temps réel)
- **Stream Analytics** : transformation et insertion dans SQL Database
- **Container Producers** : génération d'événements simulés

---

## ⚠️ **1.2 - LIMITES & RISQUES IDENTIFIÉS**

### **🔴 Problème 1 : Pas de traçabilité des vendeurs**
- Actuellement, **aucune dimension vendeur** n'existe
- Impossible de savoir quel vendeur a fourni un produit
- **Impact métier** : pas d'analyse par vendeur, pas de commission calculable

### **🔴 Problème 2 : Qualité des données hétérogènes**
- Les vendeurs tiers envoient des données via leurs propres systèmes
- Risques : prix négatifs, champs manquants, incohérences
- **Aucun mécanisme de validation** actuellement en place

### **🔴 Problème 3 : Pas de gestion des variations**
- Si un vendeur change de statut (actif → suspendu), **l'historique est perdu**
- Impossible d'analyser les performances d'un vendeur sur différentes périodes

### **🔴 Problème 4 : Sécurité et cloisonnement inexistants**
- Tous les utilisateurs voient toutes les données
- Un vendeur pourrait voir les données d'un concurrent
- **Non-conforme RGPD** (pas de traçabilité des accès)

### **🔴 Problème 5 : Pas de sources externes**
- Actuellement, seules les données internes Event Hubs sont intégrées
- Besoin d'intégrer : stocks, prix dynamiques, disponibilités depuis API externes

---

## ✅ **1.3 - PROPOSITION DU NOUVEAU MODÈLE DIMENSIONNEL**

### **Architecture cible : Modèle en étoile étendu**

```
┌─────────────────┐
│  dim_customer   │
└────────┬────────┘
         │
         │         ┌─────────────────┐
         │         │   dim_vendor    │◄─── NOUVEAU (SCD Type 2)
         │         └────────┬────────┘
         │                  │
    ┌────▼──────────────────▼────┐
    │      fact_order            │
    │  (+ vendor_id)             │
    └────┬───────────────────────┘
         │
         │         ┌─────────────────┐
         └────────►│  dim_product    │
                   │  (+ vendor_id)  │
                   │  (+ quality_flag)│
                   └─────────────────┘

┌─────────────────┐
│ fact_clickstream│
└─────────────────┘

┌─────────────────┐
│   fact_stock    │◄─── NOUVEAU (source externe)
└─────────────────┘

┌─────────────────┐
│log_data_quality │◄─── NOUVEAU (traçabilité erreurs)
└─────────────────┘
```

---

## 📐 **1.4 - STRATÉGIE DE GESTION DES VARIATIONS (SCD)**

### **Choix de modélisation : SCD Type 2 pour `dim_vendor`**

**Pourquoi SCD Type 2 ?**
- Les vendeurs peuvent changer de statut (actif, suspendu, banni)
- Besoin d'analyser les performances **avant/après** un changement de statut
- Conservation de l'historique complet

**Implémentation :**
```sql
dim_vendor :
- vendor_id (PK)
- vendor_name
- vendor_email
- vendor_status (active, suspended, banned)
- vendor_category (premium, standard, basic)
- start_date       ← début validité
- end_date         ← fin validité (NULL si actuel)
- is_current       ← flag version active
- version          ← numéro de version
```

**Exemple d'évolution :**
```
Version 1 : Vendeur "TechShop" actif du 2024-01-01 au 2024-06-15
Version 2 : Vendeur "TechShop" suspendu du 2024-06-16 au 2024-07-01
Version 3 : Vendeur "TechShop" actif depuis 2024-07-02
```

---

# 🔵 **BLOC 2 : ÉVOLUTION DU MODÈLE DE DONNÉES**

## 🛠️ **2.1 - NOUVEAU FICHIER `dwh_schema.sql`**

Voici le **nouveau schéma SQL complet** à mettre dans ton fichier `dwh_schema.sql` :

```sql
-- ============================================================================
-- ShopNow Marketplace - Data Warehouse Schema
-- Version : 2.0 (Marketplace adaptation)
-- ============================================================================

-- ============================================================================
-- 1. DIMENSION : dim_vendor (NOUVEAU - SCD Type 2)
-- ============================================================================
-- Gestion des vendeurs avec historisation des changements (SCD Type 2)
-- Permet de tracker les évolutions de statut et catégorie dans le temps
-- ============================================================================

DROP TABLE IF EXISTS dim_vendor;
CREATE TABLE dim_vendor (
    vendor_key         INT IDENTITY(1,1) PRIMARY KEY,  -- Clé surrogate
    vendor_id          VARCHAR(50) NOT NULL,           -- ID métier du vendeur
    vendor_name        NVARCHAR(255) NOT NULL,
    vendor_email       NVARCHAR(255),
    vendor_status      NVARCHAR(50),                   -- active, suspended, banned
    vendor_category    NVARCHAR(50),                   -- premium, standard, basic
    registration_date  DATETIME,
    
    -- Colonnes SCD Type 2
    start_date         DATETIME NOT NULL DEFAULT GETDATE(),
    end_date           DATETIME NULL,                  -- NULL = version actuelle
    is_current         BIT NOT NULL DEFAULT 1,         -- 1 = version active
    version            INT NOT NULL DEFAULT 1,
    
    -- Métadonnées
    created_at         DATETIME DEFAULT GETDATE(),
    updated_at         DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_vendor_id ON dim_vendor(vendor_id);
CREATE INDEX idx_vendor_current ON dim_vendor(vendor_id, is_current);

-- ============================================================================
-- 2. DIMENSION : dim_customer (Inchangé)
-- ============================================================================

DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
    customer_id VARCHAR(50) PRIMARY KEY,
    name        NVARCHAR(255),
    email       NVARCHAR(255),
    address     NVARCHAR(500),
    city        NVARCHAR(100),
    country     NVARCHAR(100),
    created_at  DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 3. DIMENSION : dim_product (MODIFIÉ)
-- ============================================================================
-- Ajout de vendor_id et data_quality_flag pour traçabilité
-- ============================================================================

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
    product_id        VARCHAR(50) PRIMARY KEY,
    vendor_id         VARCHAR(50),                     -- NOUVEAU : lien vers vendeur
    name              NVARCHAR(255),
    category          NVARCHAR(100),
    price             DECIMAL(18, 2),                  -- NOUVEAU : prix unitaire
    data_quality_flag NVARCHAR(20) DEFAULT 'valid',   -- NOUVEAU : valid, invalid, pending
    data_quality_reason NVARCHAR(500),                -- NOUVEAU : raison si invalide
    created_at        DATETIME DEFAULT GETDATE(),
    updated_at        DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_product_vendor ON dim_product(vendor_id);
CREATE INDEX idx_product_quality ON dim_product(data_quality_flag);

-- ============================================================================
-- 4. FAIT : fact_order (MODIFIÉ)
-- ============================================================================
-- Ajout de vendor_id pour analyse par vendeur
-- ============================================================================

DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order (
    order_id        VARCHAR(50),
    product_id      VARCHAR(50),
    customer_id     VARCHAR(50),
    vendor_id       VARCHAR(50),                      -- NOUVEAU : vendeur de la commande
    quantity        INT,
    unit_price      DECIMAL(18, 2),
    total_amount    DECIMAL(18, 2),                   -- NOUVEAU : quantité * prix
    status          NVARCHAR(50),
    order_timestamp DATETIME,
    created_at      DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_order_vendor ON fact_order(vendor_id);
CREATE INDEX idx_order_customer ON fact_order(customer_id);
CREATE INDEX idx_order_product ON fact_order(product_id);
CREATE INDEX idx_order_timestamp ON fact_order(order_timestamp);

-- ============================================================================
-- 5. FAIT : fact_clickstream (Inchangé)
-- ============================================================================

DROP TABLE IF EXISTS fact_clickstream;
CREATE TABLE fact_clickstream (
    event_id        VARCHAR(50) PRIMARY KEY,
    session_id      VARCHAR(50),
    user_id         VARCHAR(50),
    url             NVARCHAR(MAX),
    event_type      NVARCHAR(50),
    event_timestamp DATETIME,
    created_at      DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_clickstream_user ON fact_clickstream(user_id);
CREATE INDEX idx_clickstream_timestamp ON fact_clickstream(event_timestamp);

-- ============================================================================
-- 6. FAIT : fact_stock (NOUVEAU)
-- ============================================================================
-- Stock produits fourni par les vendeurs (source externe)
-- ============================================================================

DROP TABLE IF EXISTS fact_stock;
CREATE TABLE fact_stock (
    stock_id          VARCHAR(50) PRIMARY KEY,
    product_id        VARCHAR(50) NOT NULL,
    vendor_id         VARCHAR(50) NOT NULL,
    available_quantity INT NOT NULL,
    reserved_quantity  INT DEFAULT 0,
    warehouse_location NVARCHAR(255),
    last_updated      DATETIME NOT NULL,
    created_at        DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_stock_product ON fact_stock(product_id);
CREATE INDEX idx_stock_vendor ON fact_stock(vendor_id);

-- ============================================================================
-- 7. LOG : log_data_quality (NOUVEAU)
-- ============================================================================
-- Traçabilité des erreurs et anomalies de qualité de données
-- ============================================================================

DROP TABLE IF EXISTS log_data_quality;
CREATE TABLE log_data_quality (
    log_id          INT IDENTITY(1,1) PRIMARY KEY,
    vendor_id       VARCHAR(50),
    source_table    NVARCHAR(100),                    -- ex: dim_product, fact_order
    record_id       VARCHAR(50),                      -- ID de l'enregistrement problématique
    issue_type      NVARCHAR(100),                    -- ex: missing_field, invalid_price
    issue_description NVARCHAR(MAX),
    raw_data        NVARCHAR(MAX),                    -- Données brutes JSON pour analyse
    detected_at     DATETIME DEFAULT GETDATE()
);

CREATE INDEX idx_quality_vendor ON log_data_quality(vendor_id);
CREATE INDEX idx_quality_detected ON log_data_quality(detected_at);

-- ============================================================================
-- 8. VUE : vw_data_quality_report (NOUVEAU)
-- ============================================================================
-- Vue agrégée pour reporting qualité par vendeur
-- ============================================================================

CREATE VIEW vw_data_quality_report AS
SELECT 
    vendor_id,
    issue_type,
    COUNT(*) as error_count,
    MAX(detected_at) as last_error_date
FROM log_data_quality
WHERE detected_at >= DATEADD(day, -7, GETDATE())  -- 7 derniers jours
GROUP BY vendor_id, issue_type;

-- ============================================================================
-- 9. STORED PROCEDURE : sp_update_vendor_scd (NOUVEAU)
-- ============================================================================
-- Gestion automatique des variations SCD Type 2 sur dim_vendor
-- ============================================================================

CREATE PROCEDURE sp_update_vendor_scd
    @vendor_id VARCHAR(50),
    @vendor_name NVARCHAR(255),
    @vendor_email NVARCHAR(255),
    @vendor_status NVARCHAR(50),
    @vendor_category NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @current_status NVARCHAR(50);
    DECLARE @current_category NVARCHAR(50);
    DECLARE @max_version INT;
    
    -- Récupérer la version actuelle
    SELECT 
        @current_status = vendor_status,
        @current_category = vendor_category,
        @max_version = version
    FROM dim_vendor
    WHERE vendor_id = @vendor_id AND is_current = 1;
    
    -- Si changement détecté → créer nouvelle version
    IF (@current_status != @vendor_status OR @current_category != @vendor_category)
    BEGIN
        -- Fermer l'ancienne version
        UPDATE dim_vendor
        SET 
            end_date = GETDATE(),
            is_current = 0,
            updated_at = GETDATE()
        WHERE vendor_id = @vendor_id AND is_current = 1;
        
        -- Insérer la nouvelle version
        INSERT INTO dim_vendor (
            vendor_id, vendor_name, vendor_email, 
            vendor_status, vendor_category, 
            start_date, is_current, version
        )
        VALUES (
            @vendor_id, @vendor_name, @vendor_email,
            @vendor_status, @vendor_category,
            GETDATE(), 1, @max_version + 1
        );
    END
    ELSE
    BEGIN
        -- Mise à jour simple si pas de changement structurel
        UPDATE dim_vendor
        SET 
            vendor_name = @vendor_name,
            vendor_email = @vendor_email,
            updated_at = GETDATE()
        WHERE vendor_id = @vendor_id AND is_current = 1;
    END
END;

-- ============================================================================
-- FIN DU SCHEMA
-- ============================================================================
```

---

## 📝 **2.2 - MODIFICATIONS À FAIRE DANS TON CODE**

### **✅ Étape 1 : Remplacer `dwh_schema.sql`**

Remplace le contenu de ton fichier `dwh_schema.sql` par le code ci-dessus.

---

### **✅ Étape 2 : Données de test pour `dim_vendor`**

Pour tester, tu peux ajouter des vendeurs fictifs. Crée un fichier `seed_vendors.sql` :

```sql
-- Insertion de vendeurs de test
INSERT INTO dim_vendor (vendor_id, vendor_name, vendor_email, vendor_status, vendor_category, registration_date)
VALUES 
('V001', 'TechShop', 'contact@techshop.com', 'active', 'premium', '2024-01-15'),
('V002', 'HomeDecor', 'info@homedecor.com', 'active', 'standard', '2024-02-20'),
('V003', 'FashionHub', 'sales@fashionhub.com', 'active', 'basic', '2024-03-10');
```

---

## 🎯 **2.3 - RÉSUMÉ DES CHANGEMENTS**

| Élément | Action | Raison |
|---------|--------|--------|
| **dim_vendor** | ✅ CRÉÉ | Traçabilité des vendeurs + SCD Type 2 |
| **dim_product** | 🔧 MODIFIÉ | Ajout `vendor_id`, `data_quality_flag` |
| **fact_order** | 🔧 MODIFIÉ | Ajout `vendor_id`, `total_amount` |
| **fact_stock** | ✅ CRÉÉ | Intégration stocks externes |
| **log_data_quality** | ✅ CRÉÉ | Traçabilité erreurs |
| **vw_data_quality_report** | ✅ CRÉÉ | Reporting qualité |
| **sp_update_vendor_scd** | ✅ CRÉÉ | Automatisation SCD Type 2 |

---

## 🚀 **PROCHAINES ÉTAPES (dans BLOC 1 & 2)**

1. **Valider ce schéma** : Est-ce qu'il correspond à tes attentes ?
2. **Modifier les producers Python** : ajouter `vendor_id` dans les événements générés
3. **Modifier Stream Analytics** : adapter les queries pour insérer `vendor_id`

**👉 Est-ce que tu valides ce schéma ? Ou tu veux qu'on ajuste quelque chose avant de continuer ?**