Parfait ! On va structurer le projet **bloc par bloc** en suivant les exigences des compétences **C16** et **C17**, adaptées au contexte **ShopNow Marketplace**.

---

## 📋 **PLAN DE TRAVAIL - DÉCOUPAGE EN BLOCS**

Voici les **blocs** à traiter pour ton projet :

### **🔵 BLOC 1 : ANALYSE & CONCEPTION**
*Analyser l'impact de la transition Marketplace sur le DWH existant*

**Livrables :**
- Analyse de l'architecture actuelle
- Identification des limites et risques
- Proposition du nouveau modèle dimensionnel (ajout `dim_vendor`)
- Stratégie de gestion des variations (SCD)

---

### **🔵 BLOC 2 : ÉVOLUTION DU MODÈLE DE DONNÉES**
*Adapter le schéma pour intégrer les vendeurs et les nouvelles sources*

**Livrables Terraform :**
- Modification de `dwh_schema.sql` :
  - Ajout de `dim_vendor` (avec gestion SCD Type 2)
  - Modification de `dim_product` (ajout `vendor_id`, `data_quality_flag`)
  - Modification de `fact_order` (ajout `vendor_id`)
  - Ajout de `fact_stock` (nouvelle source externe)
  - Ajout de `log_data_quality` (traçabilité qualité)

---

### **🔵 BLOC 3 : JOURNALISATION & ALERTES**
*Mettre en place le logging et les alertes pour la supervision*

**Livrables Terraform :**
- Configuration **Log Analytics Workspace** (Azure Monitor)
- Activation des **Diagnostic Settings** sur :
  - SQL Database
  - Event Hubs
  - Stream Analytics
  - Container Instances
- Configuration des **Action Groups** pour alertes (email/SMS)
- Création de **règles d'alerte** :
  - Échec des jobs Stream Analytics
  - Erreurs SQL (deadlocks, timeouts)
  - Event Hubs throttling
  - Container restart

---

### **🔵 BLOC 4 : BACKUP & PLAN DE MAINTENANCE**
*Planifier les sauvegardes et la maintenance*

**Livrables Terraform :**
- Configuration **Azure SQL Database Backup** :
  - Backup automatique (Point-in-Time Restore)
  - Long-Term Retention (LTR) : hebdomadaire, mensuel, annuel
- Création d'**Azure Automation Account** avec Runbooks pour :
  - Vérification des backups
  - Nettoyage des anciens logs
  - Maintenance des index SQL

**Livrables Documentation :**
- Planning de maintenance (hebdo/mensuel)
- Procédures de restore
- SLA définis (disponibilité, RTO, RPO)

---

### **🔵 BLOC 5 : SUPERVISION & MONITORING**
*Tableau de bord pour suivre l'état du DWH*

**Livrables Terraform :**
- Création d'un **Azure Dashboard** avec :
  - Métriques Stream Analytics (événements traités, erreurs)
  - Métriques SQL (DTU usage, connexions, deadlocks)
  - Métriques Event Hubs (messages entrants, throttling)
  - Logs d'erreurs en temps réel

**Alternative :**
- Configuration **Azure Monitor Workbook** (plus avancé)

---

### **🔵 BLOC 6 : GESTION DES ACCÈS & SÉCURITÉ**
*Cloisonnement des données par vendeur + conformité RGPD*

**Livrables Terraform :**
- Création de **Azure AD Groups** pour les vendeurs
- Configuration de **Row-Level Security (RLS)** dans SQL Database :
  - Chaque vendeur ne voit que ses données
  - Les équipes internes ont accès complet
- Création de **SQL Users** par vendeur avec permissions restrictives
- Activation du **SQL Auditing** pour traçabilité RGPD

**Livrables Documentation :**
- Registre des traitements RGPD
- Procédures de droit d'accès / suppression (RGPD)
- Matrice des accès

---

### **🔵 BLOC 7 : INTÉGRATION DE NOUVELLES SOURCES**
*Ajouter des sources externes (API stocks, données vendeurs)*

**Livrables Terraform :**
- Ajout d'un nouvel **Event Hub** : `vendor-updates`
- Création d'une **Azure Function** (ou Logic App) pour :
  - Récupérer les données d'API externes (stocks, prix)
  - Valider et envoyer vers Event Hub
- Mise à jour du **Stream Analytics Job** :
  - Nouvel input : `InputVendorUpdates`
  - Nouvelle transformation vers `fact_stock`

---

### **🔵 BLOC 8 : GESTION DES VARIATIONS (SCD)**
*Historiser les changements dans les dimensions (ex: statut vendeur)*

**Livrables Terraform/SQL :**
- Implémentation **SCD Type 2** sur `dim_vendor` :
  - Colonnes : `start_date`, `end_date`, `is_current`, `version`
- Modification des **Stream Analytics queries** pour détecter les changements
- Création d'une **Stored Procedure** pour gérer les updates SCD

---

### **🔵 BLOC 9 : QUALITÉ DES DONNÉES**
*Détecter et isoler les données problématiques des vendeurs*

**Livrables Terraform/SQL :**
- Ajout de règles de validation dans **Stream Analytics** :
  - Prix < 0 → flag `quality_issue`
  - Champs manquants → log dans `log_data_quality`
- Création d'une vue SQL `vw_data_quality_report` pour analyse
- Alerte automatique si seuil d'erreurs dépassé

---

### **🔵 BLOC 10 : DOCUMENTATION PROFESSIONNELLE**
*Livrable final pour le jury*

**Contenu du rapport (5-10 pages) :**
1. **Introduction** : contexte ShopNow, enjeux Marketplace
2. **Analyse de l'existant** : limites de l'architecture actuelle
3. **Évolutions proposées** :
   - Nouveau modèle de données
   - Architecture de supervision
   - Gestion des accès et sécurité
4. **Gestion des variations** : implémentation SCD Type 2
5. **Plan de maintenance** : backups, SLA, monitoring
6. **Conformité RGPD** : traçabilité, procédures
7. **Conclusion** : bénéfices et évolutions futures

---

## 🎯 **PROPOSITION : PAR QUEL BLOC COMMENCER ?**

Je te propose de commencer par **BLOC 1 & 2** (Analyse + Évolution du modèle) car c'est la **fondation** de tout le projet.

**Action immédiate :**
1. ✅ Analyser le schéma actuel (`dwh_schema.sql`)
2. ✅ Proposer le nouveau schéma avec `dim_vendor` + SCD Type 2
3. ✅ Modifier `dwh_schema.sql` en Terraform

---

**🚀 Est-ce que tu veux qu'on démarre avec le BLOC 1 & 2 (Analyse + Nouveau modèle de données) ?**
