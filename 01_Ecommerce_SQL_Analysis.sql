CREATE DATABASE ecommerce_analysis;
USE ecommerce_analysis;
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    sex VARCHAR(10),
    customer_age INT,
    tenure INT
);
CREATE TABLE baskets (
    customer_id INT,
    product_id INT,
    basket_date DATE,
    basket_count INT
);
-- Count total customers
SELECT COUNT(*) FROM customer_details;

-- Shows 10 rows from customer details dataset
SELECT * FROM customer_details
LIMIT 10;

SELECT COUNT(*) FROM basket_details;

SELECT COUNT(*) AS total_customers FROM customer_details;

SELECT COUNT(*) AS total_transactions FROM basket_details;
SELECT MIN(basket_date), MAX(basket_date)
FROM basket_details;

SELECT SUM(basket_count) AS total_items_sold
FROM basket_details;

-- PURPOSE: Average Items Per Transaction
SELECT 
    SUM(basket_count) / COUNT(*) AS avg_items_per_transaction
FROM basket_details;

-- PURPOSE: Average Items Per Customer 
SELECT 
    SUM(basket_count) / COUNT(DISTINCT customer_id) AS avg_items_per_customer
FROM basket_details;

-- PURPOSE: Sales Contribution By Age Group
SELECT 
    CASE 
        WHEN c.customer_age < 25 THEN 'Under 25'
        WHEN c.customer_age BETWEEN 25 AND 40 THEN '25-40'
        WHEN c.customer_age BETWEEN 41 AND 60 THEN '41-60'
        ELSE '60+'
    END AS age_group,
    SUM(b.basket_count) AS total_items_sold
FROM customer_details c
JOIN basket_details b
    ON c.customer_id = b.customer_id
GROUP BY age_group
ORDER BY total_items_sold DESC;

-- PURPOSE: Identify Repeat Customers
SELECT 
    customer_id,
    COUNT(*) AS number_of_orders
FROM basket_details
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY number_of_orders DESC;

-- PURPOSE: RFM Base Metrics Per Customer
SELECT 
    customer_id,
    MAX(basket_date) AS last_purchase_date,
    COUNT(*) AS frequency,
    SUM(basket_count) AS monetary_value
FROM basket_details
GROUP BY customer_id;

-- PURPOSE: RFM Analysis With Recency
SELECT 
    customer_id,
    DATEDIFF(
        (SELECT MAX(basket_date) FROM basket_details),
        MAX(basket_date)
    ) AS recency_days,
    COUNT(*) AS frequency,
    SUM(basket_count) AS monetary_value
FROM basket_details
GROUP BY customer_id;

-- PURPOSE: Basic Customer Segmentation (RFM Based)
SELECT 
    customer_id,
    CASE 
        WHEN COUNT(*) >= 10 THEN 'High Frequency'
        WHEN COUNT(*) BETWEEN 5 AND 9 THEN 'Medium Frequency'
        ELSE 'Low Frequency'
    END AS frequency_segment,
    SUM(basket_count) AS total_items
FROM basket_details
GROUP BY customer_id;

-- PURPOSE: Create Base RFM Metrics
SELECT 
    customer_id,
    MAX(basket_date) AS last_purchase_date,
    COUNT(*) AS frequency,
    SUM(basket_count) AS monetary
FROM basket_details
GROUP BY customer_id;

-- PURPOSE: Calculate Recency, Frequency, Monetary
SELECT 
    customer_id,
    DATEDIFF(
        (SELECT MAX(basket_date) FROM basket_details),
        MAX(basket_date)
    ) AS recency_days,
    COUNT(*) AS frequency,
    SUM(basket_count) AS monetary
FROM basket_details
GROUP BY customer_id;

-- PURPOSE: Full RFM Scoring
WITH rfm_base AS (
    SELECT 
        customer_id,
        DATEDIFF(
            (SELECT MAX(basket_date) FROM basket_details),
            MAX(basket_date)
        ) AS recency_days,
        COUNT(*) AS frequency,
        SUM(basket_count) AS monetary
    FROM basket_details
    GROUP BY customer_id
)

SELECT 
    customer_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days ASC) AS recency_score,
    NTILE(5) OVER (ORDER BY frequency DESC) AS frequency_score,
    NTILE(5) OVER (ORDER BY monetary DESC) AS monetary_score
FROM rfm_base;

-- PURPOSE: Customer Segmentation Based on RFM
WITH rfm_scores AS (
    SELECT 
        customer_id,
        NTILE(5) OVER (ORDER BY DATEDIFF(
            (SELECT MAX(basket_date) FROM basket_details),
            MAX(basket_date)
        ) ASC) AS r_score,
        NTILE(5) OVER (ORDER BY COUNT(*) DESC) AS f_score,
        NTILE(5) OVER (ORDER BY SUM(basket_count) DESC) AS m_score
    FROM basket_details
    GROUP BY customer_id
)

SELECT *,
    CASE 
        WHEN r_score = 5 AND f_score >= 4 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score <= 2 THEN 'At Risk'
        ELSE 'Regular Customers'
    END AS customer_segment
FROM rfm_scores;

-- PURPOSE: Pareto 80/20 Customer Contribution Analysis
WITH customer_sales AS (
    SELECT 
        customer_id,
        SUM(basket_count) AS total_items
    FROM basket_details
    GROUP BY customer_id
),

ranked_customers AS (
    SELECT 
        customer_id,
        total_items,
        SUM(total_items) OVER () AS overall_sales,
        SUM(total_items) OVER (ORDER BY total_items DESC) AS cumulative_sales
    FROM customer_sales
)

SELECT 
    customer_id,
    total_items,
    ROUND((cumulative_sales / overall_sales) * 100, 2) AS cumulative_percentage
FROM ranked_customers
ORDER BY total_items DESC;

-- PURPOSE: Customer Retention Rate Calculation
WITH repeat_customers AS (
    SELECT 
        customer_id
    FROM basket_details
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)

SELECT 
    ROUND(
        (COUNT(*) / (SELECT COUNT(DISTINCT customer_id) FROM basket_details)) * 100,
        2
    ) AS retention_rate_percentage
FROM repeat_customers;

-- PURPOSE: Percentage of Customers Contributing 80% Sales
-- =====================================

WITH customer_sales AS (
    SELECT 
        customer_id,
        SUM(basket_count) AS total_items
    FROM basket_details
    GROUP BY customer_id
),

ranked AS (
    SELECT 
        customer_id,
        total_items,
        SUM(total_items) OVER () AS overall_sales,
        SUM(total_items) OVER (ORDER BY total_items DESC) AS cumulative_sales,
        COUNT(*) OVER () AS total_customers
    FROM customer_sales
)

SELECT 
    ROUND(
        COUNT(*) * 100.0 / MAX(total_customers),
        2
    ) AS percentage_of_customers_for_80_percent
FROM ranked
WHERE cumulative_sales <= 0.8 * overall_sales;