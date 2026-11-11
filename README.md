# Northwind Traders — Étude d’analyse commerciale avec MySQL

## 1. Présentation du projet

Ce projet consiste à réaliser une étude d’analyse commerciale à partir de la base de données relationnelle **Northwind Traders**, en utilisant MySQL.

L’objectif est de comprendre la structure des données, d’évaluer leur qualité, de préparer un environnement de travail fiable, puis d’exploiter les données pour répondre à des questions métier concernant les ventes, les produits, les clients, les employés et les expéditions.

La démarche suivie est comprendre les données, justifier les décisions de préparation, définir les indicateurs, analyser les résultats et formuler des conclusions compréhensibles par un responsable métier.

## 2. Contexte métier et périmètre des données

Northwind Traders est une entreprise fictive spécialisée dans la distribution de produits alimentaires. La base utilisée contient sept tables :

| Table | Nombre de lignes | Nombre de colonnes | Rôle dans l’analyse |
|---|---:|---:|---|
| `orders` | 830 | 9 | Informations générales sur les commandes |
| `customers` | 91 | 6 | Informations sur les clients |
| `employees` | 9 | 6 | Employés associés au traitement des commandes et hiérarchie |
| `shippers` | 3 | 2 | Sociétés d’expédition associées aux commandes |
| `order_details` | 2 155 | 5 | Détail des produits, quantités, prix et remises par commande |
| `products` | 77 | 6 | Informations sur les produits |
| `categories` | 8 | 3 | Catégories auxquelles appartiennent les produits |

Ces nombres correspondent à l’observation initiale des tables utilisées dans ce projet.

### Grain des tables

La compréhension du niveau de détail de chaque table est importante pour éviter les erreurs d’analyse :

- `orders` contient une ligne par commande.
- `order_details` contient une ligne par produit associé à une commande. Une commande peut donc être représentée par plusieurs lignes dans cette table.
- `products`, `customers`, `employees`, `shippers` et `categories` contiennent les informations de référence des entités correspondantes.

Le nombre de lignes de `order_details` (2 155) est supérieur à celui de `orders` (830). Cela est cohérent avec le fait qu'une commande peut contenir plusieurs produits.

## 3. Compréhension des relations entre les tables

La première étape a consisté à comprendre comment les entités métier sont liées entre elles et à identifier les cardinalités.

### Relations identifiées

- **Customers — Orders :** un client peut passer plusieurs commandes ; chaque commande est rattachée à un client. Il s’agit d’une relation **1 à N**.
- **Employees — Orders :** un employé peut être associé au traitement de plusieurs commandes ; chaque commande référence un employé. Il s’agit d’une relation **1 à N**.
- **Shippers — Orders :** un expéditeur peut être associé à plusieurs commandes ; chaque commande référence un expéditeur. Il s’agit d’une relation **1 à N**.
- **Orders — Order Details :** une commande peut contenir plusieurs lignes de commande ; chaque ligne appartient à une commande. Il s’agit d’une relation **1 à N**.
- **Products — Order Details :** un produit peut apparaître dans plusieurs lignes de commande ; chaque ligne concerne un produit. Il s’agit d’une relation **1 à N**.
- **Categories — Products :** une catégorie peut regrouper plusieurs produits ; chaque produit est associé à une catégorie. Il s’agit d’une relation **1 à N**.
- **Employees — Employees :** la colonne `reportsTo` représente une relation hiérarchique réflexive. Un employé peut superviser plusieurs employés ; un employé peut référencer un manager. Pour l’employé au sommet de la hiérarchie, `reportsTo` peut être `NULL`.

La relation **many-to-many** concerne `Orders` et `Products` : une commande peut contenir plusieurs produits et un produit peut être présent dans plusieurs commandes. La table associative `order_details` résout cette relation et porte également les attributs propres à chaque ligne : `unitPrice`, `quantity` et `discount`.

Les relations entre `Orders` et `Customers`, `Employees` ou `Shippers` ne sont donc pas many-to-many : dans le modèle utilisé, chacune de ces relations est de type one-to-many.

### ERD — Schéma relationnel

L’ERD ci-dessous représente les sept tables, leurs clés primaires, leurs clés étrangères et les relations décrites précédemment.

![ERD de la base Northwind Traders](documentation/erd_northwind.png)


## 4. Méthodologie de préparation des données

### 4.1 Création des tables staging

Les tables de travail ont été créées à partir des tables importées à l’aide de `CREATE TABLE ... LIKE`, puis alimentées avec `INSERT INTO ... SELECT`.

**Pourquoi ce choix ?**

L’objectif était de préserver les tables d’origine telles qu’elles ont été importées. En cas d’erreur pendant la préparation, les données sources restent disponibles pour comparaison ou reprise.

Les transformations et les analyses ont donc été réalisées sur les tables `*_staging`, et non directement sur les tables brutes.

### 4.2 Vérification et correction des types de données

Après l’importation, les types de colonnes ont été inspectés puis ajustés selon la nature des informations et leur utilisation analytique.

Cette étape était nécessaire car l’outil d’importation peut déduire les types à partir du contenu observé et proposer des types inadaptés ou trop génériques.

Quelques décisions importantes :

- Les identifiants texte des clients ont été conservés dans un type texte (`CHAR`), et non convertis en nombres.
- Les dates des commandes ont été définies avec le type `DATE`.
- Les valeurs monétaires, notamment les prix unitaires et le fret, ont été définies en `DECIMAL`.
- `discount` a été défini en `DECIMAL(3,2)`, car la remise est stockée sous forme de fraction : par exemple `0.15` représente 15 %.
- `reportsTo` a été converti en type entier, car il référence l’identifiant numérique d’un autre employé.

Un point important concernait la colonne `discount` : lors de l’importation, les premiers enregistrements observés étant des zéros, le type déduit pouvait être entier. Or, les valeurs décimales de remise doivent être conservées pour éviter de fausser le calcul du chiffre d’affaires.

Les types ont été choisis en fonction des besoins du projet, sans chercher à sur-architecturer la base.

### 4.3 Ajout progressif des contraintes

Les contraintes ont été ajoutées progressivement, après vérification des données nécessaires à leur mise en place.

- Les clés primaires identifient les enregistrements de manière unique.
- Les clés étrangères matérialisent les relations entre les tables.
- `order_details` utilise une clé primaire composite (`orderID`, `productID`) : un produit apparaît au maximum une fois dans une commande dans le modèle retenu.
- `employees.reportsTo` référence `employees.employeeID` pour représenter la hiérarchie des employés.
- La relation entre `products` et `categories` est matérialisée par `products.categoryID`.

Cette progression permettait de contrôler les données et de traiter les valeurs qui empêchaient l’ajout des contraintes avant de les activer.

Deux comportements de suppression ont également été définis dans les relations staging :

- `ON DELETE RESTRICT` entre `orders_staging` et `order_details_staging` et entre `products_staging` et `order_details_staging`: Cette règle empêche la suppression d'une commande ou d'un produit tant que des lignes de commande y font référence. Ce choix permet de conserver les données historiques nécessaires au suivi des ventes, aux analyses et aux contrôles de l'entreprise, les commandes annulées et les produits obsolètes sont donc conservés plutôt que supprimés physiquement.
- `ON DELETE SET NULL` pour `employees_staging.reportsTo` : si un manager est supprimé, la référence hiérarchique des employés concernés devient `NULL` plutôt que de supprimer ces employés.

Ces règles concernent les tables staging du projet et doivent être choisies avec prudence dans une base opérationnelle réelle.

### 4.4 Traitement des valeurs manquantes et des chaînes vides

Deux cas particuliers ont été examinés :

**Dates d’expédition (`ShippedDate`)**

Certaines valeurs étaient importées sous forme de chaînes vides (`''`). Elles ont été converties en `NULL`, car une chaîne vide n’est pas une date valide et ne doit pas être confondue avec une date connue.

Les `NULL` ont ensuite été conservés : aucune date d’expédition n’a été inventée ou imputée. Une valeur manquante ne permet pas, à elle seule, de conclure qu’une commande n’a pas été expédiée. De même, la présence d’un `ShipperID` ou d’un montant `Freight` ne suffit pas à prouver que l’expédition a effectivement eu lieu.

**Hiérarchie des employés (`ReportsTo`)**

Une valeur vide a été convertie en `NULL`. Dans cette relation hiérarchique, l’employé situé au sommet de la hiérarchie n’a pas de manager référencé. `NULL` représente donc correctement l’absence de supérieur hiérarchique.

### 4.5 Audit de qualité et décisions de nettoyage

Les contrôles effectués ont porté sur :

- Les valeurs manquantes est dans toutes les colonnes.
- Les doublons dans la table de transaction `orders_staging` sans inclure les identifiants parce qu'ils sont uniques.
- Les types et formats des dates, prix, quantités et remises.
- Les valeurs invalides : prix négatifs, quantités nulles ou négatives, remises hors de l’intervalle attendu, fret négatif.
- Les incohérences de dates.
- La cohérence des relations entre les tables.

Les contrôles de doublons ont notamment comparé des combinaisons d’attributs d’une commande comme: CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate et Freight. Aucun doublon n’a été retenu comme doublon confirmé à supprimer sur la base des critères testés. Une combinaison d’attributs identique peut toutefois correspondre à deux commandes légitimes : ce contrôle sert donc à repérer des cas à examiner, et non à supprimer automatiquement des lignes.

**Bilan de la préparation :** les contrôles n’ont pas conduit à une suppression de commandes ou de lignes de commande. Les actions réalisées ont principalement consisté à corriger les types, normaliser les chaînes vides en `NULL` lorsque cela était justifié, puis ajouter les contraintes relationnelles. Les valeurs manquantes de `ShippedDate` ont été conservées pour ne pas inventer d’information.

## 5. Méthode de calcul des indicateurs

Le chiffre d’affaires est calculé à partir des lignes de commande, en tenant compte des remises :

`CA net = unitPrice × quantity × (1 - discount)`

La remise est donc déduite du montant brut de chaque ligne.

La valeur moyenne d’une commande (Average Order Value — AOV) est calculée comme suit :

`AOV = chiffre d’affaires net / nombre de commandes distinctes`

Lorsqu’une requête joint `orders` à `order_details`, une commande apparaît autant de fois qu’elle possède de lignes de détail. Pour cette raison, le nombre de commandes doit être calculé avec `COUNT(DISTINCT orderID)` lorsque la jointure multiplie les lignes de commande.

Cette distinction entre le niveau de détail des tables et le niveau de calcul du KPI est essentielle pour éviter les doubles comptages.

## 6. Analyses commerciales réalisées

### Vue générale de l’activité(Analyse Exploratoire Des Données EDA)
- Nombre de commandes, de clients, de produits et de catégories.
- Quantité totale d’unités vendues.
- Chiffre d’affaires net total.
- Valeur moyenne des commandes.

### Analyse temporelle
- Évolution annuelle du chiffre d’affaires.
- Évolution annuelle du nombre de commandes.
- Identification, pour chaque année, des mois avec le chiffre d’affaires le plus élevé et le plus faible.

### Analyse des produits et catégories
- Produits les plus vendus en quantité.
- Produits générant le plus et le moins de chiffre d’affaires.
- Chiffre d’affaires et quantités vendues par catégorie.
- Produits apparaissant le plus souvent dans des lignes de commande remisées.
- Valeur totale des remises accordées par produit.

### Analyse des clients
- Clients ayant effectué au moins une commande.
- Clients générant le plus de chiffre d’affaires.
- Clients passant le plus de commandes.
- Valeur moyenne des commandes par client.
- Quantités achetées par client et par produit.
- Contribution individuelle des principaux clients au chiffre d’affaires total.

### Analyse des employés
- Nombre de commandes associées à chaque employé.
- Chiffre d’affaires associé à chaque employé.
- Valeur moyenne des commandes par employé.
- Comparaison des classements selon le volume de commandes, le chiffre d’affaires et l’AOV.

### Analyse des expéditions
- Nombre de commandes ayant une date d’expédition renseignée.
- Délai moyen entre la commande et l’expédition.
- Nombre de commandes dont la date d’expédition est postérieure à la date requise.
- Nombre de commandes associées à chaque expéditeur.
- Délai moyen commande-expédition par expéditeur.

Comme indiqué précédemment, Les valeurs `NULL` ont été conservées sans imputation. Une date d’expédition manquante ne signifie pas nécessairement que la commande n’a pas été expédiée, tout comme la présence d’un `ShipperID` ou d’un montant `Freight` ne confirme pas qu’elle l’a été.

## 7. Principaux enseignements métier

Les constats ci-dessous reprennent les résultats et les comparaisons examinés pendant l’analyse. Les classements sont présentés sans inventer de montants ou de pourcentages qui ne figurent pas dans les éléments disponibles.

### 7.1 Le volume de commandes et le chiffre d’affaires donnent des classements proches, mais pas identiques

Les employés 4, 3 et 1 occupent les trois premières positions à la fois selon le nombre de commandes et selon le chiffre d’affaires associé.

Cependant, les classements ne sont pas identiques pour tous les employés : les employés 2 et 8, par exemple, échangent leurs positions entre le classement par nombre de commandes et celui par chiffre d’affaires.

**Interprétation :** le nombre de commandes traitées et le chiffre d’affaires associé sont deux indicateurs liés, mais ils ne mesurent pas la même chose. Le volume d’activité ne suffit donc pas à expliquer à lui seul la contribution au chiffre d’affaires.

### 7.2 L’AOV apporte une lecture complémentaire de l’activité des employés

Les classements par AOV montrent des différences importantes :

| Employé | Rang CA | Rang nombre de commandes | Rang AOV |
|---:|---:|---:|---:|
| 4 | 1 | 1 | 7 |
| 9 | 7 | 8 | 1 |
| 5 | 9 | 9 | 4 |
| 2 | 4 | 5 | 2 |
| 8 | 5 | 4 | 8 |

L’employé 4 est premier en chiffre d’affaires et en volume de commandes, mais septième en AOV. À l’inverse, l’employé 9 est premier en AOV alors qu’il se classe septième en chiffre d’affaires et huitième en nombre de commandes. L’employé 5 est dernier en chiffre d’affaires et en nombre de commandes, mais quatrième en AOV.

**Interprétation :** un chiffre d’affaires élevé peut être associé à un volume important de commandes, tandis qu’un AOV élevé peut refléter des commandes de valeur moyenne plus importante. Il est donc préférable de croiser ces trois indicateurs plutôt que d’évaluer l’activité avec un seul classement.

**Limite :** ces résultats ne permettent pas de conclure qu’un employé est plus performant qu’un autre. Le portefeuille clients, les produits vendus, les remises et la répartition des commandes peuvent influencer les résultats.

### 7.3 Les produits les plus vendus en quantité ne sont pas nécessairement ceux qui génèrent le plus de chiffre d’affaires

L’analyse distingue le classement des produits selon les unités vendues de celui selon le chiffre d’affaires net.

**Interprétation :** le volume vendu et la contribution au chiffre d’affaires sont deux dimensions différentes. Le prix unitaire et les remises peuvent expliquer qu’un produit vendu en grande quantité ne soit pas nécessairement le premier en revenu.

Cette distinction est utile pour ne pas confondre popularité d’un produit et contribution financière.

### 7.4 L’analyse des achats en grandes quantités dépend de la définition retenue

Les quantités ont été examinées à deux niveaux : le total acheté par client, puis le total acheté par combinaison client-produit. Les quantités par ligne de commande ont également été inspectées.

**Interprétation :** un client peut acheter une quantité cumulée importante d’un produit au fil de plusieurs commandes sans avoir passé une commande individuelle en grande quantité. Il faut donc distinguer les achats cumulés d’un client et les commandes ponctuelles en volume important.

### 7.5 Les dates d’expédition manquantes limitent l’interprétation des indicateurs logistiques

Plusieurs commandes ont une `ShippedDate` manquante alors qu’un expéditeur et un montant de fret sont renseignés. L’examen de certains enregistrements a également montré des commandes passées le même jour, avec la même date requise et le même expéditeur, dont l’une possède une date d’expédition et l’autre non.

**Interprétation :** la complétude des dates d’expédition est un point de vigilance pour le suivi logistique. Le nombre calculé avec `ShippedDate IS NOT NULL` représente les commandes disposant d’une date d’expédition renseignée ; il ne doit pas être présenté sans nuance comme le nombre certain de toutes les commandes physiquement expédiées.

**Limite :** la similarité entre certaines commandes ne prouve pas que les commandes sans date ont été expédiées. Les valeurs `NULL` ont donc été conservées et les calculs fondés sur une date d’expédition les excluent.

### 7.6 Le délai calculé mesure le temps entre la commande et son expédition, pas le transport jusqu’au client

Le délai moyen est calculé avec `DATEDIFF(ShippedDate, OrderDate)` et uniquement sur les commandes dont la date d’expédition est renseignée.

**Interprétation :** cet indicateur mesure le temps écoulé entre la création de la commande et son expédition. Il permet de comparer le délai commande-expédition entre les expéditeurs associés aux commandes.

**Limite :** il ne mesure pas le temps de transport du colis ni le délai réel de réception par le client, car aucune date de livraison effective n’est utilisée dans cette analyse.

### 7.7 Une expédition après la date requise ne prouve pas à elle seule une livraison tardive

La comparaison entre `ShippedDate` et `RequiredDate` identifie les commandes expédiées après la date demandée par le client.

**Interprétation :** cet indicateur peut signaler un retard dans le traitement ou l’expédition de la commande par rapport à la date souhaitée.

**Limite :** `RequiredDate` correspond à la date souhaitée par le client et `ShippedDate` à la date d’expédition. Sans date de livraison effective, il n’est pas possible de conclure que le client a réellement reçu sa commande en retard.

- Les dates `ShippedDate` manquantes limitent les analyses fondées sur les expéditions.

## 8. Techniques SQL mobilisées

Le projet utilise notamment :

- Sélection et filtrage : `SELECT`, `WHERE`, `ORDER BY`, `LIMIT`.
- Agrégations : `COUNT`, `SUM`, `AVG`, `ROUND`, `GROUP BY`.
- Jointures : `INNER JOIN`.
- Sous-requêtes : `EXISTS`.
- CTE : `WITH`.
- Fonctions de fenêtrage : `ROW_NUMBER()` et `DENSE_RANK()`.
- Fonctions temporelles : `YEAR()`, `MONTHNAME()`, `DATEDIFF()`.
- Logique conditionnelle : `CASE WHEN`.
- Structure relationnelle : `PRIMARY KEY`, `FOREIGN KEY`, `ALTER TABLE`.


## 9. Conclusion

Ce projet m’a permis de mettre en pratique une démarche complète d’analyse commerciale avec SQL : comprendre une base relationnelle, examiner sa qualité, préserver les données sources, justifier les décisions de préparation, calculer des indicateurs et interpréter les résultats dans un contexte métier.


## 10. Reproduction du projet

1. Importer les sept tables sources dans une base MySQL.
2. Sélectionner la base de données concernée.
3. Exécuter le script SQL dans l’ordre des sections : création des tables staging, audit et préparation, puis analyses exploratoires et métier.
4. Consulter les résultats des requêtes pour retrouver les indicateurs et classements présentés dans ce README.

Le script fourni a été préparé pour le schéma de données utilisé dans ce projet. Il est recommandé de vérifier les noms de colonnes, les types et les contraintes si une autre version de Northwind est utilisée.
