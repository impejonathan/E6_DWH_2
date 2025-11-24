Parfait ! On reste sur le **BLOC 1 & 2** jusqu'à ce que tu me dises de passer au suivant. 💪

---

# 🔵 **BLOC 1 : ANALYSE & CONCEPTION**

## **1.1 - ANALYSE DE L'ARCHITECTURE ACTUELLE**

### **📊 Modèle actuel du DWH ShopNow**

Ton DWH actuel suit un **modèle en étoile (Star Schema)** avec :

**Tables de dimensions :**
- `dim_customer` : informations clients
- `dim_product` : catalogue produits

**Tables de faits :**
- `fact_order` : transactions de commandes
- `fact_clickstream` : comportement utilisateur

**Alimentation :**
- **Temps réel** : Azure Event Hubs → Stream Analytics → SQL Database
- **Event Hubs** : `orders`, `products`, `clickstream`
- **Producteurs** : Container Instances qui génèrent des événements simulés

---

### **🚨 LIMITES DE L'ARCHITECTURE ACTUELLE POUR LE MARKETPLACE**

#### **❌ Problème 1 : Absence de traçabilité des vendeurs**
- Actuellement, **aucune information sur les vendeurs** n'est stockée
- Impossible de savoir quel produit appartient à quel vendeur
- Impossible d'analyser les performances par vendeur
- **Impact** : pas de pilotage multi-vendeurs

#### **❌ Problème 2 : Pas d'historisation des changements**
- Si un vendeur change de statut (actif → suspendu) ou de catégorie, **l'historique est perdu**
- Impossible d'analyser l'évolution des vendeurs dans le temps
- **Impact** : perte de contexte analytique

#### **❌ Problème 3 : Qualité des données non contrôlée**
- Les données des vendeurs tiers peuvent être **erronées ou incomplètes**
- Aucun flag de qualité dans les tables actuelles
- Aucun log des anomalies détectées
- **Impact** : risque de corrompre les analyses

#### **❌ Problème 4 : Modèle rigide pour nouvelles sources**
- L'architecture actuelle ne prévoit pas l'intégration de sources externes (API stocks, prix, disponibilités)
- **Impact** : impossibilité d'enrichir les données facilement

#### **❌ Problème 5 : Sécurité et cloisonnement inexistants**
- Tous les utilisateurs ont accès à toutes les données
- Pas de mécanisme pour restreindre l'accès par vendeur
- **Impact** : non-conformité sécurité et risque de fuite de données

---

### **🎯 OBJECTIFS DE LA REFONTE**

1. **Ajouter la dimension vendeur** avec historisation (SCD Type 2)
2. **Tracer la qualité des données** (flags, logs d'anomalies)
3. **Préparer l'intégration de nouvelles sources** (stocks, prix)
4. **Sécuriser l'accès** (cloisonnement par vendeur)
5. **Maintenir la cohérence analytique** malgré l'hétérogénéité des sources

---

Parfait ! Voici les deux schémas détaillés en markdown à insérer entre 1.2 et 1.3 :

---

## **1.2 - COMPARAISON DES MODÈLES DE DONNÉES**

### **1.2.1 - ANCIEN MODÈLE DIMENSIONNEL (Avant Marketplace)**

#### **📊 Schéma en étoile simple (Star Schema)**

```
                    ┌─────────────────────────────┐
                    │      dim_customer           │
                    │─────────────────────────────│
                    │ • customer_id (PK)          │
                    │ • name                      │
                    │ • email                     │
                    │ • address                   │
                    │ • city                      │
                    │ • country                   │
                    └──────────────┬──────────────┘
                                   │
                                   │
                    ┌──────────────▼──────────────┐
            ┌───────┤       fact_order            │
            │       │─────────────────────────────│
            │       │ • order_id                  │
            │       │ • product_id (FK)           │
            │       │ • customer_id (FK)          │
            │       │ • quantity                  │
            │       │ • unit_price                │
            │       │ • status                    │
            │       │ • order_timestamp           │
            │       └─────────────────────────────┘
            │
            │
    ┌───────▼─────────────────────┐
    │      dim_product            │
    │─────────────────────────────│
    │ • product_id (PK)           │
    │ • name                      │
    │ • category                  │
    └─────────────────────────────┘


    ┌─────────────────────────────┐
    │    fact_clickstream         │
    │─────────────────────────────│
    │ • event_id (PK)             │
    │ • session_id                │
    │ • user_id                   │
    │ • url                       │
    │ • event_type                │
    │ • event_timestamp           │
    └─────────────────────────────┘
```

#### **📋 Détail des tables AVANT évolution**

| **Table** | **Colonnes** | **Type** | **Description** |
|-----------|-------------|----------|-----------------|
| **dim_customer** | customer_id | VARCHAR(50) PK | Identifiant client |
| | name | NVARCHAR(255) | Nom du client |
| | email | NVARCHAR(255) | Email |
| | address | NVARCHAR(500) | Adresse |
| | city | NVARCHAR(100) | Ville |
| | country | NVARCHAR(100) | Pays |
| **dim_product** | product_id | VARCHAR(50) PK | Identifiant produit |
| | name | NVARCHAR(255) | Nom du produit |
| | category | NVARCHAR(100) | Catégorie |
| **fact_order** | order_id | VARCHAR(50) | Identifiant commande |
| | product_id | VARCHAR(50) FK | Produit commandé |
| | customer_id | VARCHAR(50) FK | Client |
| | quantity | INT | Quantité |
| | unit_price | DECIMAL(18,2) | Prix unitaire |
| | status | NVARCHAR(50) | Statut commande |
| | order_timestamp | DATETIME | Date commande |
| **fact_clickstream** | event_id | VARCHAR(50) PK | Identifiant événement |
| | session_id | VARCHAR(50) | Session utilisateur |
| | user_id | VARCHAR(50) | Utilisateur |
| | url | NVARCHAR(MAX) | URL visitée |
| | event_type | NVARCHAR(50) | Type événement |
| | event_timestamp | DATETIME | Date événement |

---

### **1.2.2 - NOUVEAU MODÈLE DIMENSIONNEL PROPOSÉ (Après Marketplace)**

#### **📐 Schéma en étoile étendu (Extended Star Schema)**

```
                    ┌─────────────────────────────┐
                    │      dim_customer           │
                    │─────────────────────────────│
                    │ • customer_id (PK)          │
                    │ • name                      │
                    │ • email                     │
                    │ • address                   │
                    │ • city                      │
                    │ • country                   │
                    │ + gdpr_consent       ✨NEW  │
                    │ + last_consent_date  ✨NEW  │
                    └──────────────┬──────────────┘
                                   │
                                   │
                    ┌──────────────▼──────────────┐
            ┌───────┤       fact_order            │──────┐
            │       │─────────────────────────────│      │
            │       │ • order_id                  │      │
            │       │ • product_id (FK)           │      │
            │       │ • customer_id (FK)          │      │
            │       │ + vendor_id (FK)     ✨NEW  │      │
            │       │ • quantity                  │      │
            │       │ • unit_price                │      │
            │       │ + total_amount       ✨NEW  │      │
            │       │ + commission         ✨NEW  │      │
            │       │ • status                    │      │
            │       │ + data_quality_flag  ✨NEW  │      │
            │       │ • order_timestamp           │      │
            │       └─────────────────────────────┘      │
            │                                            │
            │                                            │
    ┌───────▼─────────────────────┐      ┌─────────────▼────────────────┐
    │      dim_product            │      │      dim_vendor        ✨NEW │
    │─────────────────────────────│      │──────────────────────────────│
    │ • product_id (PK)           │      │ • vendor_id (PK)             │
    │ + vendor_id (FK)     ✨NEW  │      │ • vendor_business_key        │
    │ • name                      │      │ • vendor_name                │
    │ • category                  │      │ • vendor_email               │
    │ + price              ✨NEW  │      │ • vendor_status              │
    │ + data_quality_flag  ✨NEW  │      │ • vendor_category            │
    │ + last_updated       ✨NEW  │      │ • commission_rate            │
    └─────────────────────────────┘      │ • country                    │
                                         │ • start_date      (SCD Type 2)│
                                         │ • end_date        (SCD Type 2)│
                                         │ • is_current      (SCD Type 2)│
                                         │ • version         (SCD Type 2)│
                                         └──────────────────────────────┘

    ┌─────────────────────────────┐      ┌──────────────────────────────┐
    │    fact_clickstream         │      │      fact_stock        ✨NEW │
    │─────────────────────────────│      │──────────────────────────────│
    │ • event_id (PK)             │      │ • stock_id (PK)              │
    │ • session_id                │      │ • vendor_id (FK)             │
    │ • user_id                   │      │ • product_id (FK)            │
    │ • url                       │      │ • quantity_available         │
    │ • event_type                │      │ • last_update                │
    │ • event_timestamp           │      │ • source_system              │
    └─────────────────────────────┘      └──────────────────────────────┘


    ┌──────────────────────────────────────────────────────┐
    │      log_data_quality                          ✨NEW │
    │──────────────────────────────────────────────────────│
    │ • log_id (PK, IDENTITY)                              │
    │ • event_type                                         │
    │ • vendor_id                                          │
    │ • error_type                                         │
    │ • error_description                                  │
    │ • raw_data                                           │
    │ • detected_at                                        │
    │ • severity                                           │
    └──────────────────────────────────────────────────────┘
```

#### **📋 Détail des tables APRÈS évolution**

##### **🔵 Tables MODIFIÉES**

| **Table** | **Colonnes** | **Type** | **Statut** | **Description** |
|-----------|-------------|----------|------------|-----------------|
| **dim_customer** | customer_id | VARCHAR(50) PK | Inchangé | Identifiant client |
| | name | NVARCHAR(255) | Inchangé | Nom du client |
| | email | NVARCHAR(255) | Inchangé | Email |
| | address | NVARCHAR(500) | Inchangé | Adresse |
| | city | NVARCHAR(100) | Inchangé | Ville |
| | country | NVARCHAR(100) | Inchangé | Pays |
| | **gdpr_consent** | **BIT** | **✨ NOUVEAU** | Consentement RGPD |
| | **last_consent_date** | **DATETIME** | **✨ NOUVEAU** | Date consentement |
| **dim_product** | product_id | VARCHAR(50) PK | Inchangé | Identifiant produit |
| | **vendor_id** | **VARCHAR(50) FK** | **✨ NOUVEAU** | Lien vers vendeur |
| | name | NVARCHAR(255) | Inchangé | Nom du produit |
| | category | NVARCHAR(100) | Inchangé | Catégorie |
| | **price** | **DECIMAL(18,2)** | **✨ NOUVEAU** | Prix unitaire |
| | **data_quality_flag** | **NVARCHAR(20)** | **✨ NOUVEAU** | Indicateur qualité |
| | **last_updated** | **DATETIME** | **✨ NOUVEAU** | Date dernière MAJ |
| **fact_order** | order_id | VARCHAR(50) | Inchangé | Identifiant commande |
| | product_id | VARCHAR(50) FK | Inchangé | Produit commandé |
| | customer_id | VARCHAR(50) FK | Inchangé | Client |
| | **vendor_id** | **VARCHAR(50) FK** | **✨ NOUVEAU** | Vendeur |
| | quantity | INT | Inchangé | Quantité |
| | unit_price | DECIMAL(18,2) | Inchangé | Prix unitaire |
| | **total_amount** | **DECIMAL(18,2)** | **✨ NOUVEAU** | Montant total |
| | **commission** | **DECIMAL(18,2)** | **✨ NOUVEAU** | Commission vendeur |
| | status | NVARCHAR(50) | Inchangé | Statut commande |
| | **data_quality_flag** | **NVARCHAR(20)** | **✨ NOUVEAU** | Indicateur qualité |
| | order_timestamp | DATETIME | Inchangé | Date commande |

##### **🆕 Tables NOUVELLES**

| **Table** | **Colonnes** | **Type** | **Description** |
|-----------|-------------|----------|-----------------|
| **dim_vendor** | vendor_id | VARCHAR(50) PK | Identifiant technique vendeur |
| **(SCD Type 2)** | vendor_business_key | VARCHAR(50) | ID métier immuable |
| | vendor_name | NVARCHAR(255) | Nom du vendeur |
| | vendor_email | NVARCHAR(255) | Email contact |
| | vendor_status | NVARCHAR(50) | Statut : ACTIVE, SUSPENDED, PENDING |
| | vendor_category | NVARCHAR(100) | Catégorie : GOLD, SILVER, BRONZE |
| | commission_rate | DECIMAL(5,2) | Taux de commission (%) |
| | country | NVARCHAR(100) | Pays du vendeur |
| | start_date | DATETIME | Date début validité (SCD) |
| | end_date | DATETIME | Date fin validité (SCD) |
| | is_current | BIT | Enregistrement actuel (SCD) |
| | version | INT | Numéro de version (SCD) |
| **fact_stock** | stock_id | VARCHAR(50) PK | Identifiant stock |
| | vendor_id | VARCHAR(50) FK | Vendeur |
| | product_id | VARCHAR(50) FK | Produit |
| | quantity_available | INT | Quantité disponible |
| | last_update | DATETIME | Date mise à jour |
| | source_system | NVARCHAR(100) | Système source (API, fichier) |
| **log_data_quality** | log_id | INT IDENTITY PK | Identifiant log |
| | event_type | NVARCHAR(50) | Type : ORDER, PRODUCT, STOCK |
| | vendor_id | VARCHAR(50) | Vendeur concerné |
| | error_type | NVARCHAR(100) | Type erreur |
| | error_description | NVARCHAR(MAX) | Description erreur |
| | raw_data | NVARCHAR(MAX) | Données brutes (JSON) |
| | detected_at | DATETIME | Date détection |
| | severity | NVARCHAR(20) | Gravité : WARNING, ERROR, CRITICAL |

---

#### **📊 Résumé des changements**

| **Catégorie** | **Avant** | **Après** | **Évolution** |
|---------------|-----------|-----------|---------------|
| **Tables dimensions** | 2 | 3 | +1 (dim_vendor) |
| **Tables faits** | 2 | 3 | +1 (fact_stock) |
| **Tables logs** | 0 | 1 | +1 (log_data_quality) |
| **Colonnes dim_customer** | 6 | 8 | +2 (RGPD) |
| **Colonnes dim_product** | 3 | 7 | +4 (vendeur, qualité) |
| **Colonnes fact_order** | 7 | 11 | +4 (vendeur, commission, qualité) |
| **Gestion SCD** | ❌ Non | ✅ Type 2 sur dim_vendor | Historisation complète |
| **Traçabilité qualité** | ❌ Non | ✅ Oui | Logs + flags |
| **Sécurité vendeurs** | ❌ Non | ✅ Oui | Cloisonnement possible |



---

## **1.3 - STRATÉGIE DE GESTION DES VARIATIONS (SCD)**

### **🔄 Slowly Changing Dimensions - Types utilisés**

#### **SCD Type 1 : Écrasement (utilisé pour `dim_product`)**
- Les modifications **écrasent** les anciennes valeurs
- Pas d'historique conservé
- **Utilisé pour** : prix, description (informations non critiques pour l'analyse historique)

#### **SCD Type 2 : Historisation complète (utilisé pour `dim_vendor`)**
- Chaque modification crée une **nouvelle ligne**
- L'historique est conservé avec `start_date`, `end_date`, `is_current`
- **Utilisé pour** : statut vendeur, catégorie, taux de commission

**Exemple de gestion SCD Type 2 pour `dim_vendor` :**

```sql
-- Version 1 : Vendeur créé en janvier
vendor_id | vendor_business_key | vendor_name | status  | start_date  | end_date | is_current | version
ABC123-1  | ABC123             | VendorX     | PENDING | 2025-01-01  | 2025-02-15 | 0        | 1

-- Version 2 : Vendeur activé en février
ABC123-2  | ABC123             | VendorX     | ACTIVE  | 2025-02-15  | NULL     | 1        | 2
```

**Requête pour récupérer la version actuelle :**
```sql
SELECT * FROM dim_vendor WHERE is_current = 1 AND vendor_business_key = 'ABC123';
```

**Requête pour récupérer l'état à une date donnée :**
```sql
SELECT * FROM dim_vendor 
WHERE vendor_business_key = 'ABC123'
  AND '2025-01-15' BETWEEN start_date AND ISNULL(end_date, '9999-12-31');
```

---

## **1.4 - IMPACTS SUR L'ARCHITECTURE**

### **🔄 Modifications Stream Analytics nécessaires**

**Nouveaux inputs à ajouter :**
- `InputVendorData` → nouvel Event Hub pour les mises à jour vendeurs
- `InputStockData` → pour les données de stock

**Nouvelles transformations :**
1. Extraction des infos vendeurs depuis les events
2. Détection des anomalies de qualité (prix négatif, champs manquants)
3. Génération des flags de qualité
4. Calcul des commissions

**Nouveaux outputs :**
- `OutputDimVendor` → vers `dim_vendor`
- `OutputFactStock` → vers `fact_stock`
- `OutputLogQuality` → vers `log_data_quality`

---

## **📝 RÉSUMÉ DU BLOC 1**

✅ **Analyse complétée** : limites identifiées, risques évalués  
✅ **Nouveau modèle proposé** : ajout `dim_vendor`, `fact_stock`, `log_data_quality`  
✅ **Stratégie SCD définie** : Type 2 pour vendeurs, Type 1 pour produits  
✅ **Impacts architecture** : modifications Stream Analytics, nouveaux Event Hubs  

---

# 🔵 **BLOC 2 : ÉVOLUTION DU MODÈLE DE DONNÉES (CODE TERRAFORM)**

Maintenant, on va **concrétiser** cette analyse en modifiant le fichier `dwh_schema.sql`.

---

## **2.1 - NOUVEAU FICHIER `dwh_schema.sql` COMPLET**

Voici le nouveau schéma SQL à utiliser dans ton projet :

```sql
-- ============================================================================
-- ShopNow Data Warehouse Schema - Version Marketplace
-- ============================================================================
-- Évolutions :
-- - Ajout de dim_vendor avec gestion SCD Type 2
-- - Ajout de fact_stock pour suivi des stocks vendeurs
-- - Ajout de log_data_quality pour traçabilité des anomalies
-- - Modification de dim_product (ajout vendor_id, quality_flag)
-- - Modification de fact_order (ajout vendor_id, quality_flag, commission)
-- ============================================================================

-- ============================================================================
-- 1. DIMENSION CUSTOMER (inchangée)
-- ============================================================================
DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
    customer_id       VARCHAR(50) PRIMARY KEY,
    name              NVARCHAR(255),
    email             NVARCHAR(255),
    address           NVARCHAR(500),
    city              NVARCHAR(100),
    country           NVARCHAR(100),
    gdpr_consent      BIT DEFAULT 1,
    last_consent_date DATETIME DEFAULT GETDATE()
);

-- ============================================================================
-- 2. DIMENSION VENDOR (NOUVELLE - SCD Type 2)
-- ============================================================================
DROP TABLE IF EXISTS dim_vendor;
CREATE TABLE dim_vendor (
    vendor_id           VARCHAR(50) PRIMARY KEY,
    vendor_business_key VARCHAR(50) NOT NULL,        -- ID métier immuable
    vendor_name         NVARCHAR(255) NOT NULL,
    vendor_email        NVARCHAR(255),
    vendor_status       NVARCHAR(50),                -- ACTIVE, SUSPENDED, PENDING
    vendor_category     NVARCHAR(100),               -- GOLD, SILVER, BRONZE
    commission_rate     DECIMAL(5,2) DEFAULT 5.00,   -- Taux de commission (%)
    country             NVARCHAR(100),
    -- Colonnes SCD Type 2
    start_date          DATETIME NOT NULL DEFAULT GETDATE(),
    end_date            DATETIME NULL,
    is_current          BIT NOT NULL DEFAULT 1,
    version             INT NOT NULL DEFAULT 1
);

-- Index pour optimiser les requêtes SCD Type 2
CREATE INDEX idx_vendor_business_key ON dim_vendor(vendor_business_key, is_current);
CREATE INDEX idx_vendor_dates ON dim_vendor(start_date, end_date);

-- ============================================================================
-- 3. DIMENSION PRODUCT (Modifiée)
-- ============================================================================
DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
    product_id         VARCHAR(50) PRIMARY KEY,
    vendor_id          VARCHAR(50),                  -- AJOUT : lien vers vendeur
    name               NVARCHAR(255),
    category           NVARCHAR(100),
    price              DECIMAL(18,2),                -- AJOUT : prix unitaire
    data_quality_flag  NVARCHAR(20) DEFAULT 'OK',   -- AJOUT : OK, WARNING, ERROR
    last_updated       DATETIME DEFAULT GETDATE(),  -- AJOUT : date de MAJ
    FOREIGN KEY (vendor_id) REFERENCES dim_vendor(vendor_id)
);

CREATE INDEX idx_product_vendor ON dim_product(vendor_id);

-- ============================================================================
-- 4. FACT ORDER (Modifiée)
-- ============================================================================
DROP TABLE IF EXISTS fact_order;
CREATE TABLE fact_order (
    order_id          VARCHAR(50),
    product_id        VARCHAR(50),
    customer_id       VARCHAR(50),
    vendor_id         VARCHAR(50),                  -- AJOUT : vendeur
    quantity          INT,
    unit_price        DECIMAL(18, 2),
    total_amount      DECIMAL(18, 2),               -- AJOUT : montant total
    commission        DECIMAL(18, 2),               -- AJOUT : commission vendeur
    status            NVARCHAR(50),
    data_quality_flag NVARCHAR(20) DEFAULT 'OK',   -- AJOUT : flag qualité
    order_timestamp   DATETIME,
    FOREIGN KEY (vendor_id) REFERENCES dim_vendor(vendor_id)
);

CREATE INDEX idx_order_vendor ON fact_order(vendor_id);
CREATE INDEX idx_order_timestamp ON fact_order(order_timestamp);

-- ============================================================================
-- 5. FACT CLICKSTREAM (inchangée)
-- ============================================================================
DROP TABLE IF EXISTS fact_clickstream;
CREATE TABLE fact_clickstream (
    event_id        VARCHAR(50) PRIMARY KEY,
    session_id      VARCHAR(50),
    user_id         VARCHAR(50),
    url             NVARCHAR(MAX),
    event_type      NVARCHAR(50),
    event_timestamp DATETIME
);

-- ============================================================================
-- 6. FACT STOCK (NOUVELLE)
-- ============================================================================
DROP TABLE IF EXISTS fact_stock;
CREATE TABLE fact_stock (
    stock_id           VARCHAR(50) PRIMARY KEY,
    vendor_id          VARCHAR(50) NOT NULL,
    product_id         VARCHAR(50) NOT NULL,
    quantity_available INT NOT NULL,
    last_update        DATETIME NOT NULL,
    source_system      NVARCHAR(100),               -- Système source (API, fichier)
    FOREIGN KEY (vendor_id) REFERENCES dim_vendor(vendor_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);

CREATE INDEX idx_stock_vendor_product ON fact_stock(vendor_id, product_id);

-- ============================================================================
-- 7. LOG DATA QUALITY (NOUVELLE - Traçabilité)
-- ============================================================================
DROP TABLE IF EXISTS log_data_quality;
CREATE TABLE log_data_quality (
    log_id             INT IDENTITY(1,1) PRIMARY KEY,
    event_type         NVARCHAR(50) NOT NULL,       -- ORDER, PRODUCT, STOCK
    vendor_id          VARCHAR(50),
    error_type         NVARCHAR(100) NOT NULL,      -- MISSING_FIELD, INVALID_PRICE, etc.
    error_description  NVARCHAR(MAX),
    raw_data           NVARCHAR(MAX),               -- Données JSON brutes
    detected_at        DATETIME NOT NULL DEFAULT GETDATE(),
    severity           NVARCHAR(20) NOT NULL        -- WARNING, ERROR, CRITICAL
);

CREATE INDEX idx_log_vendor ON log_data_quality(vendor_id);
CREATE INDEX idx_log_detected_at ON log_data_quality(detected_at);

-- ============================================================================
-- 8. VUES UTILES
-- ============================================================================

-- Vue : Vendeurs actifs uniquement (version courante)
CREATE VIEW vw_active_vendors AS
SELECT 
    vendor_id,
    vendor_business_key,
    vendor_name,
    vendor_email,
    vendor_status,
    vendor_category,
    commission_rate,
    country,
    start_date
FROM dim_vendor
WHERE is_current = 1 AND vendor_status = 'ACTIVE';
GO

-- Vue : Rapport qualité des données par vendeur
CREATE VIEW vw_data_quality_report AS
SELECT 
    v.vendor_name,
    l.event_type,
    l.error_type,
    l.severity,
    COUNT(*) as error_count,
    MAX(l.detected_at) as last_error_date
FROM log_data_quality l
LEFT JOIN dim_vendor v ON l.vendor_id = v.vendor_id AND v.is_current = 1
GROUP BY v.vendor_name, l.event_type, l.error_type, l.severity;
GO

-- ============================================================================
-- 9. STORED PROCEDURE : Gestion SCD Type 2 pour dim_vendor
-- ============================================================================
CREATE PROCEDURE sp_upsert_vendor
    @vendor_business_key VARCHAR(50),
    @vendor_name         NVARCHAR(255),
    @vendor_email        NVARCHAR(255),
    @vendor_status       NVARCHAR(50),
    @vendor_category     NVARCHAR(100),
    @commission_rate     DECIMAL(5,2),
    @country             NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @existing_vendor_id VARCHAR(50);
    DECLARE @new_vendor_id VARCHAR(50);
    DECLARE @max_version INT;
    
    -- Vérifier si le vendeur existe déjà (version courante)
    SELECT 
        @existing_vendor_id = vendor_id
    FROM dim_vendor
    WHERE vendor_business_key = @vendor_business_key
      AND is_current = 1;
    
    -- Si le vendeur n'existe pas, le créer
    IF @existing_vendor_id IS NULL
    BEGIN
        SET @new_vendor_id = @vendor_business_key + '-1';
        
        INSERT INTO dim_vendor (
            vendor_id, vendor_business_key, vendor_name, vendor_email,
            vendor_status, vendor_category, commission_rate, country,
            start_date, end_date, is_current, version
        )
        VALUES (
            @new_vendor_id, @vendor_business_key, @vendor_name, @vendor_email,
            @vendor_status, @vendor_category, @commission_rate, @country,
            GETDATE(), NULL, 1, 1
        );
    END
    ELSE
    BEGIN
        -- Vérifier si les données ont changé
        IF EXISTS (
            SELECT 1 FROM dim_vendor
            WHERE vendor_id = @existing_vendor_id
              AND (
                  vendor_name != @vendor_name OR
                  vendor_status != @vendor_status OR
                  vendor_category != @vendor_category OR
                  commission_rate != @commission_rate
              )
        )
        BEGIN
            -- Données modifiées → SCD Type 2
            
            -- 1. Fermer l'ancienne version
            UPDATE dim_vendor
            SET end_date = GETDATE(),
                is_current = 0
            WHERE vendor_id = @existing_vendor_id;
            
            -- 2. Créer la nouvelle version
            SELECT @max_version = MAX(version)
            FROM dim_vendor
            WHERE vendor_business_key = @vendor_business_key;
            
            SET @new_vendor_id = @vendor_business_key + '-' + CAST(@max_version + 1 AS VARCHAR);
            
            INSERT INTO dim_vendor (
                vendor_id, vendor_business_key, vendor_name, vendor_email,
                vendor_status, vendor_category, commission_rate, country,
                start_date, end_date, is_current, version
            )
            VALUES (
                @new_vendor_id, @vendor_business_key, @vendor_name, @vendor_email,
                @vendor_status, @vendor_category, @commission_rate, @country,
                GETDATE(), NULL, 1, @max_version + 1
            );
        END
        -- Sinon, aucun changement → ne rien faire
    END
END;
GO

-- ============================================================================
-- FIN DU SCHEMA
-- ============================================================================
```

---

## **2.2 - REMPLACEMENT DU FICHIER DANS TON PROJET**

**Action à faire :**

1. ✅ **Remplace** le contenu de ton fichier `dwh_schema.sql` par le code ci-dessus
2. ✅ **Sauvegarde** le fichier
3. ✅ **Note** : Le script gère automatiquement :
   - Les `DROP TABLE IF EXISTS` (pas d'erreur si la table existe déjà)
   - La création des index pour optimiser les performances
   - La création des vues utiles
   - La stored procedure pour gérer le SCD Type 2

---

## **2.3 - VÉRIFICATION**

Une fois le fichier remplacé, tu pourras :

1. **Re-déployer l'infrastructure** avec Terraform (le container `db_setup` recréera les tables)
2. **Ou exécuter manuellement** le script SQL dans Azure SQL Database via Azure Data Studio ou SQL Server Management Studio

---

## **📝 RÉSUMÉ DU BLOC 2**

✅ **Nouveau schéma SQL créé** avec :
- ✅ `dim_vendor` avec SCD Type 2
- ✅ `fact_stock` pour les stocks
- ✅ `log_data_quality` pour la traçabilité
- ✅ Modifications de `dim_product` et `fact_order`
- ✅ Vues et stored procedure pour gestion SCD

✅ **Prêt à être déployé** via Terraform

---
