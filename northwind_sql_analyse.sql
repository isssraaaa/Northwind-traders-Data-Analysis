-- NORTHWIND TRADERS | ÉTUDE D'ANALYSE COMMERCIALE AVEC MYSQL
-- Démarche : tables sources -> tables staging -> contrôles qualité
--             -> préparation -> analyse exploratoire et métier
--
-- Prérequis :
--   Les sept tables sources (categories, customers, employees,
--   order_details, orders, products et shippers) doivent déjà exister
--   dans la base de données sélectionnée.
--   Ce script ne crée pas les tables sources et n'importe pas les CSV.
--
-- Remarque :
--   Les tables *_staging sont utilisées afin de préserver les tables
--   sources. Vérifier les types et les colonnes si une autre version
--   de Northwind est utilisée.


-- 01 | CRÉATION DES TABLES STAGING ET VÉRIFICATION DES TYPES

CREATE TABLE categories_staging
LIKE categories;
INSERT INTO categories_staging
SELECT *
FROM categories;

SELECT*
FROM categories_staging;

SHOW COLUMNS from categories_staging;

ALTER TABLE categories_staging
MODIFY categoryName VARCHAR(40),
MODIFY `description` VARCHAR(80),
ADD CONSTRAINT pk_categories_staging PRIMARY KEY (categoryID);

CREATE TABLE customers_staging
LIKE customers;
INSERT INTO customers_staging
SELECT *
FROM customers;

SELECT*
FROM customers_staging;

SHOW COLUMNS FROM customers_staging;

ALTER TABLE customers_staging
MODIFY customerID CHAR(5),
MODIFY companyName VARCHAR(50) NOT NULL,
MODIFY contactName VARCHAR(30),
MODIFY contactTitle VARCHAR (30),
MODIFY city VARCHAR(20),
MODIFY country VARCHAR (20),
ADD CONSTRAINT PK_cutomers_staging PRIMARY KEY(customerID);

CREATE TABLE employees_staging
LIKE employees;
INSERT INTO employees_staging
SELECT *
FROM employees;

SELECT*
FROM employees_staging;

SHOW COLUMNS FROM employees_staging;

ALTER TABLE employees_staging
MODIFY employeeName VARCHAR(50),
MODIFY title VARCHAR (50),
MODIFY city VARCHAR(30),
MODIFY country VARCHAR(10),
MODIFY reportsTo TEXT,
ADD CONSTRAINT pk_employees_staging PRIMARY KEY (employeeID);

CREATE TABLE order_details_staging
LIKE order_details;
INSERT INTO order_details_staging
SELECT *
FROM order_details;

SELECT*
FROM order_details_staging;

SHOW COLUMNS FROM order_details_staging;

ALTER TABLE order_details_staging
MODIFY unitPrice DECIMAL(5,2) NOT NULL,
MODIFY quantity INT NOT NULL,
MODIFY discount DECIMAL(3,2);

CREATE TABLE orders_staging
LIKE orders;
INSERT INTO orders_staging
SELECT *
FROM orders;

SELECT*
FROM orders_staging;

SHOW COLUMNS FROM orders_staging;

ALTER TABLE orders_staging
MODIFY customerID CHAR(5),
MODIFY freight DECIMAL(6,2),
ADD CONSTRAINT pk_orders_staging PRIMARY KEY(orderID);

CREATE TABLE products_staging
LIKE products;
INSERT INTO products_staging
SELECT *
FROM products;

SELECT *
FROM products_staging;

SHOW COLUMNS FROM products_staging;

ALTER TABLE products_staging
MODIFY productName VARCHAR(50),
MODIFY quantityPerUnit VARCHAR(50),
MODIFY unitPrice DECIMAL(5,2),
ADD CONSTRAINT pk_products_staging PRIMARY KEY(productID),
ADD CONSTRAINT fk_products_categories_staging
    FOREIGN KEY(categoryID) REFERENCES categories_staging(categoryID);

CREATE TABLE shippers_staging
LIKE shippers;
INSERT INTO shippers_staging
SELECT *
FROM shippers;

SELECT*
FROM shippers_staging;

SHOW COLUMNS FROM shippers_staging;

ALTER TABLE shippers_staging
MODIFY companyName VARCHAR(50),
ADD CONSTRAINT pk_shippers_staging PRIMARY KEY(shipperID);

-- 02 | AUDIT DE LA QUALITÉ DES DONNÉES ET PRÉPARATION
-- Vérification des valeurs manquantes

SELECT*
FROM orders_staging
WHERE orderID IS NULL
OR customerID IS NULL
OR employeeID IS NULL
OR orderDate IS NULL
OR requiredDate IS NULL
OR shippedDate IS NULL
OR shipperID IS NULL
OR freight IS NULL;

SELECT*
FROM orders_staging
WHERE shippedDate = '';

UPDATE orders_staging
SET shippedDate = NULL
WHERE shippedDate = '';

ALTER TABLE orders_staging
MODIFY orderDate DATE,
MODIFY requiredDate DATE,
MODIFY shippedDate DATE;

ALTER TABLE orders_staging
ADD CONSTRAINT fk_customers_staging FOREIGN KEY(customerID)
	REFERENCES customers_staging(customerID),
ADD CONSTRAINT fk_employees_staging FOREIGN KEY(employeeID)
	REFERENCES employees_staging(employeeID),
ADD CONSTRAINT fk_shippers_staging FOREIGN KEY(shipperID)
	REFERENCES shippers_staging(shipperID)
;

SELECT*
FROM employees_staging
WHERE reportsTo = '';

UPDATE employees_staging
SET reportsTo = NULL
WHERE reportsTo = '';

ALTER TABLE employees_staging
MODIFY reportsTo int,
ADD CONSTRAINT fk_employees_staging2 FOREIGN KEY(reportsTo)
	REFERENCES employees_staging(employeeID)
    ON UPDATE CASCADE
    ON DELETE SET NULL;

SELECT *
FROM order_details_staging
WHERE productID IS NULL
OR unitPrice IS NULL
OR quantity IS NULL
OR discount IS NULL;

ALTER TABLE order_details_staging
ADD CONSTRAINT PRIMARY KEY(orderID, productID),
ADD CONSTRAINT fk_orders_staging FOREIGN KEY(orderID)
	REFERENCES orders_staging(orderID)
    ON DELETE RESTRICT,
ADD CONSTRAINT fk_products_staging FOREIGN KEY(productID)
	REFERENCES products_staging(productID)
    ON DELETE RESTRICT
;

-- 03 | CONTRÔLES DE COHÉRENCE DES DONNÉES

SELECT*
FROM orders_staging
WHERE OrderDate > RequiredDate
OR OrderDate > ShippedDate;

SELECT*
FROM orders_staging
WHERE freight < 0;

SELECT *
FROM order_details_staging
WHERE unitPrice < 0
OR quantity <= 0
OR discount < 0
OR discount > 1;

-- 04 | RECHERCHE DE DOUBLONS 
SELECT*
FROM orders_staging;

WITH lignes_numerotees AS(
SELECT *, ROW_NUMBER()
OVER(PARTITION BY CustomerID, EmployeeID, OrderDate, RequiredDate, ShippedDate, Freight) AS numero_ligne
FROM orders_staging)
SELECT*
FROM lignes_numerotees
WHERE row_numbr > 1;

-- 05 | ANALYSE EXPLORATOIRE DES DONNÉES

SELECT*
FROM orders_staging;
SELECT*
FROM order_details_staging;

-- Nombre total de commandes
SELECT count(*)
FROM orders_staging;

-- Nombre total de clients
SELECT COUNT(*)
FROM customers_staging;

-- Nombre de produits
SELECT COUNT(*)
FROM products_staging;

-- Nombre de catégories
SELECT COUNT(*)
FROM categories_staging;

-- Nombre total d'unités vendues
SELECT SUM(quantity)
FROM order_details_staging;

-- Chiffre d'affaires total (net de remise).
-- Hypothèse de calcul : unitPrice * quantity * (1 - discount).

SELECT ROUND(SUM(unitPrice * quantity * (1-discount)), 2) AS CA
FROM order_details_staging;

 -- Valeur moyenne d'une commande (AOV) : CA net / nombre de commandes distinctes.
SELECT ROUND(SUM(unitPrice * quantity * (1-discount)) / COUNT(DISTINCT orderID), 2) AS valeur_moyenne
FROM order_details_staging;

-- 06 | ANALYSE TEMPORELLE
-- Évolution annuelle du chiffre d'affaires

SELECT
ROUND(SUM(unitPrice * quantity * (1-discount)), 2) AS chiffre_affaires,
YEAR(orderDate) AS annee
FROM orders_staging AS OS
JOIN order_details_staging AS OD
	ON OS.orderID = OD.orderID
GROUP BY annee
ORDER BY annee ASC;

-- Évolution annuelle du nombre de commandes

SELECT
	YEAR(orderDate) AS annee,
	COUNT(orderID) AS nombre_de_commandes
FROM orders_staging
GROUP BY YEAR(orderDate)
ORDER BY nombre_de_commandes DESC;

-- Le chiffre d'affaires et le nombre de commandes évoluent de manière similaire

-- Identifier, pour chaque année, les mois générant le plus et le moins de chiffre d'affaires

WITH chiffre_affaires_mensuel AS(
	SELECT
		ROUND(SUM(OD.unitPrice * OD.quantity * (1-OD.discount)),2) AS revenu,
		YEAR(os.orderDate) AS annee,
		MONTHNAME(os.orderDate) AS mois
	FROM orders_staging AS OS
	JOIN order_details_staging AS OD
		ON OS.orderID = OD.orderID
	GROUP BY YEAR(os.orderDate), MONTHNAME(os.orderDate)
),
 classement_mensuel AS(
	SELECT annee, mois, revenu,
		DENSE_RANK() OVER(PARTITION BY annee ORDER BY revenu DESC) AS rang_CA_decroissant,
        DENSE_RANK() OVER(PARTITION BY annee ORDER BY revenu ASC) AS rang_CA_croissant
	FROM chiffre_affaires_mensuel)
SELECT
	annee, mois, revenu,
    CASE
        WHEN rang_CA_decroissant = 1 AND rang_CA_croissant = 1 THEN 'un seul mois'
        WHEN rang_CA_decroissant = 1 THEN 'le mois avec le CA le plus élevé'
        WHEN rang_CA_croissant = 1 THEN 'le mois le CA le plus bas'
    END AS categorie_de_chiffre_affaires
FROM classement_mensuel
WHERE rang_CA_decroissant = 1 OR rang_CA_croissant = 1
ORDER BY annee ASC, revenu DESC;

-- 07 | ANALYSE DES PRODUITS

-- Les produits les plus vendus en quantité

SELECT p.productName, SUM(od.quantity) AS quantité_vendue
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
GROUP BY od.productID, p.productName
ORDER BY quantité_vendue DESC
LIMIT 10;

-- Les produits qui génèrent le plus de chiffre d'affaires

SELECT p.productName,
ROUND(SUM(od.unitPrice*od.quantity*(1-od.discount)),2) AS CA
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
GROUP BY od.productID, p.productName
ORDER BY CA DESC
LIMIT 10;
-- Les produits les plus vendus en quantité ne sont pas nécessairement ceux qui génèrent le plus de chiffre d'affaires

-- Les produits qui génèrent le moins de chiffre d'affaires

SELECT p.productName,
ROUND(SUM(od.unitPrice*od.quantity*(1-od.discount)),2) AS CA
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
GROUP BY od.productID, p.productName
ORDER BY CA ASC
LIMIT 10;

-- Les catégories qui génèrent le plus de chiffre d'affaires

SELECT
catg.categoryName,
ROUND(SUM(od.unitPrice*od.quantity*(1-od.discount)),2) AS CA
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
JOIN categories_staging catg
	ON p.categoryID = catg.categoryID
GROUP BY catg.categoryID, catg.categoryName
ORDER BY CA DESC;

-- Les catégories qui vendent le plus d'unités
SELECT
catg.categoryName,
SUM(od.quantity) AS quantité_vendue
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
JOIN categories_staging catg
	ON p.categoryID = catg.categoryID
GROUP BY catg.categoryID, catg.categoryName
ORDER BY quantité_vendue DESC;

-- Les produits apparaissant le plus souvent dans des lignes de commande remisées

SELECT p.productName,
COUNT(DISTINCT CASE WHEN od.discount > 0.00 THEN od.orderID END) AS nombre_commandes_avec_remise
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
GROUP BY od.productID, p.productName
ORDER BY nombre_commandes_avec_remise DESC
LIMIT 10;

-- Les produits générant la plus grande valeur totale de remises

SELECT p.productName,
ROUND(SUM(od.unitPrice * od.quantity * od.discount), 2) AS valeur_totale_remises_par_produit
FROM order_details_staging od
JOIN products_staging p
	ON od.productID = p.productID
GROUP BY od.productID, p.productName
ORDER BY valeur_totale_remises_par_produit DESC
LIMIT 10;

-- 08 | ANALYSE DES CLIENTS
-- Les clients ayant effectué au moins une commande
SELECT customerID, companyName
FROM customers_staging
WHERE EXISTS (
	SELECT customerID
    FROM orders_staging
    WHERE customers_staging.customerID = orders_staging.customerID
    );

-- Les clients générant le plus de chiffre d'affaires
SELECT CU.customerID, CU.companyName,
ROUND(SUM(od.unitPrice*od.quantity*(1-od.discount)),2) AS CA_par_client
FROM order_details_staging OD
JOIN orders_staging O
	ON OD.orderID = O.orderID
JOIN customers_staging CU
	ON O.customerID = CU.customerID
GROUP BY CU.customerID, CU.companyName
ORDER BY CA_par_client DESC
LIMIT 10;

-- Contribution des principaux clients au chiffre d'affaires total
WITH clients_principaux AS (
SELECT CU.customerID, CU.companyName,
ROUND(SUM(od.unitPrice*od.quantity*(1-od.discount)),2) AS CA_par_client
FROM order_details_staging OD
JOIN orders_staging O
	ON OD.orderID = O.orderID
JOIN customers_staging CU
	ON O.customerID = CU.customerID
GROUP BY CU.customerID, CU.companyName
ORDER BY CA_par_client DESC
LIMIT 10),
CA_total AS(
SELECT
ROUND(SUM(unitPrice * quantity * (1-discount)), 2) AS CA
FROM order_details_staging)
SELECT customerID, companyName,
ROUND((CA_par_client/CA)*100, 2) AS contribution_CA_pct
FROM clients_principaux
CROSS JOIN CA_total;

-- Les clients passant le plus de commandes
SELECT CUST.customerID, CUST.companyName,
COUNT(O.orderID) AS nombre_de_commandes
FROM customers_staging CUST
JOIN orders_staging O
	ON CUST.customerID = O.customerID
GROUP BY CUST.customerID, CUST.companyName
ORDER BY nombre_de_commandes DESC
LIMIT 10;

-- Valeur moyenne des commandes par client
SELECT CU.customerID, CU.companyName,
ROUND(SUM(OD.unitPrice * OD.quantity * (1-OD.discount))/ COUNT(DISTINCT OD.orderID), 2) AS AOV
FROM order_details_staging OD
JOIN orders_staging O
	ON OD.orderID = O.orderID
JOIN customers_staging CU
	ON O.customerID = CU.customerID
GROUP BY CU.customerID, CU.companyName;

-- Les clients ayant acheté les plus grandes quantités au total
SELECT CUST.customerID, CUST.companyName,
SUM(OD.quantity) AS quantite_totale_achetee
FROM customers_staging CUST
JOIN orders_staging O
	ON CUST.customerID = O.customerID
JOIN order_details_staging OD
	ON O.orderID = OD.orderID
GROUP BY CUST.customerID, CUST.companyName
ORDER BY quantite_totale_achetee DESC
LIMIT 10;

-- Quantités cumulées achetées par client et par produit
SELECT CUST.customerID, CUST.companyName, P.productName,
SUM(OD.quantity) AS quantite_totale_achetee
FROM customers_staging CUST
JOIN orders_staging O
	ON CUST.customerID = O.customerID
JOIN order_details_staging OD
	ON O.orderID = OD.orderID
JOIN products_staging P
	 ON OD.productID = P.productID
GROUP BY CUST.customerID, CUST.companyName, P.productName
ORDER BY quantite_totale_achetee DESC;

-- 09 | ANALYSE DES EMPLOYÉS
-- Nombre de commandes associées à chaque employé
SELECT EMP.employeeID, EMP.employeeName,
COUNT(O.orderID) AS nombre_de_commandes
FROM orders_staging O
JOIN employees_staging EMP
	ON O.employeeID = EMP.employeeID
GROUP BY EMP.employeeID, EMP.employeeName
ORDER BY nombre_de_commandes DESC;

-- Employés associés au chiffre d'affaires le plus élevé
SELECT EMP.employeeID, EMP.employeeName,
ROUND(SUM(unitPrice * quantity * (1-discount)), 2) AS CA_par_employe
FROM order_details_staging OD
JOIN orders_staging O
	ON OD.orderID = O.orderID
JOIN employees_staging EMP
	ON O.employeeID = EMP.employeeID
GROUP BY EMP.employeeID, EMP.employeeName
ORDER BY CA_par_employe DESC;

-- Les employés qui ont traité plus de commandes sont les employés qui contribuent le plus au CA.

-- Valeur moyenne des commandes par employé
SELECT EMP.employeeID, EMP.employeeName,
ROUND(SUM(OD.unitPrice * OD.quantity * (1-OD.discount))/ COUNT(DISTINCT OD.orderID), 2) AS AOV_par_employe
FROM order_details_staging OD
JOIN orders_staging O
	ON OD.orderID = O.orderID
JOIN employees_staging EMP
	ON O.employeeID = EMP.employeeID
GROUP BY EMP.employeeID, EMP.employeeName
ORDER BY AOV_par_employe DESC;
-- Certains employés traitent beaucoup de commandes mais avec une valeur moyenne faible.

-- 10 | ANALYSE DES EXPÉDITIONS
-- Nombre de commandes disposant d'une date d'expédition renseignée.
-- Précaution : une date manquante ne prouve ni que la commande a été expédiée, ni qu'elle ne l'a pas été.
SELECT COUNT(orderID) AS commandes_avec_date_expedition
FROM orders_staging
WHERE shippedDate IS NOT NULL;

-- Délai moyen entre la commande et l'expédition
SELECT ROUND(AVG(DATEDIFF(shippedDate,orderDate)),0) AS delai_moyen_expedition
FROM orders_staging
WHERE shippedDate IS NOT NULL;

-- Nombre de commandes expédiées après la date requise
SELECT COUNT(orderID)
FROM orders_staging
WHERE requiredDate < shippedDate
AND shippedDate IS NOT NULL;

-- Expéditeur associé au plus grand nombre de commandes
-- Cette requête compte les commandes associées à un expéditeur, pas uniquement celles ayant une ShippedDate renseignée.
SELECT SH.shipperID, companyName, COUNT(orderID) AS nombre_de_commandes
FROM orders_staging O
JOIN shippers_staging SH
	ON O.shipperID = SH.shipperID
GROUP BY SH.shipperID, companyName
ORDER BY nombre_de_commandes DESC;

-- Expéditeur présentant le délai moyen commande-expédition le plus court
-- DATEDIFF(ShippedDate, OrderDate) mesure le temps entre la commande et son expédition,
-- et non le temps de transport jusqu'à la réception par le client.
SELECT O.shipperID, companyName,
ROUND(AVG(DATEDIFF(shippedDate,orderDate)),0) AS delai_moyen_expedition
FROM orders_staging O
JOIN shippers_staging SH
	ON O.shipperID = SH.shipperID
WHERE O.shippedDate IS NOT NULL
GROUP BY SH.shipperID, companyName
ORDER BY delai_moyen_expedition;


-- 11 | PÉRIMÈTRE ET PRÉCAUTIONS D'INTERPRÉTATION
-- 1. Le périmètre de cette version comprend sept tables :
--    categories, customers, employees, orders, order_details,
--    shippers et products.
--    utilisée. L'analyse des fournisseurs est donc hors périmètre.
-- 2. Les valeurs NULL de ShippedDate sont conservées. La présence
--    d'un ShipperID ou d'un Freight ne prouve pas à elle seule
--    qu'une commande a effectivement été expédiée.
-- 3. La comparaison entre ShippedDate et RequiredDate identifie les
--    commandes expédiées après la date demandée. Aucune date de
--    livraison effective n'est disponible pour mesurer le retard réel.
-- 4. Le chiffre d'affaires est calculé au niveau de la ligne de commande
--    à partir de UnitPrice, Quantity et Discount.

