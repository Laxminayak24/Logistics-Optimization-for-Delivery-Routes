CREATE DATABASE DHL_Logistics;
USE DHL_Logistics;

CREATE TABLE Orders (
    Order_ID VARCHAR(20) PRIMARY KEY,
    Customer_ID VARCHAR(20),
    Order_Date DATETIME,
    Route_ID VARCHAR(20),
    Warehouse_ID VARCHAR(20),
    Order_Amount DECIMAL(10,2),
    Delivery_Type VARCHAR(20),
    Payment_Mode VARCHAR(20)
);


CREATE TABLE Routes (
    Route_ID VARCHAR(20) PRIMARY KEY,
    Source_City VARCHAR(50),
    Source_Country VARCHAR(50),
    Destination_City VARCHAR(50),
    Destination_Country VARCHAR(50),
    Distance_KM INT,
    Avg_Transit_Time_Hours INT
);


CREATE TABLE Warehouses (
    Warehouse_ID VARCHAR(20) PRIMARY KEY,
    City VARCHAR(50),
    Country VARCHAR(50),
    Capacity_per_day INT,
    Manager_Name VARCHAR(100)
);


CREATE TABLE Delivery_Agents (
    Agent_ID VARCHAR(20) PRIMARY KEY,
    Agent_Name VARCHAR(100),
    Zone VARCHAR(50),
    Zone_Country VARCHAR(50),
    Experience_Years INT,
    Avg_Rating DECIMAL(3,2)
);
CREATE TABLE Shipments (
    Shipment_ID VARCHAR(20) PRIMARY KEY,
    Order_ID VARCHAR(20),
    Agent_ID VARCHAR(20),
    Route_ID VARCHAR(20),
    Warehouse_ID VARCHAR(20),
    Pickup_Date DATETIME,
    Delivery_Date DATETIME,
    Delivery_Status VARCHAR(20),
    Delay_Hours DECIMAL(10,2),
    Delivery_Feedback VARCHAR(20),
    Delay_Reason VARCHAR(100),
    Expected_Delivery_Date DATETIME
);

SELECT COUNT(*) FROM Orders;
SELECT COUNT(*) FROM Routes;
SELECT COUNT(*) FROM Warehouses;
SELECT COUNT(*) FROM Delivery_Agents;
SELECT COUNT(*) FROM Shipments;

-- ============================================
-- TASK 1 : DATA CLEANING & PREPARATION
-- ============================================

SELECT Order_ID, COUNT(*) AS Duplicate_Count
FROM Orders
GROUP BY Order_ID
HAVING COUNT(*) > 1;

SELECT Shipment_ID, COUNT(*) AS Duplicate_Count
FROM Shipments
GROUP BY Shipment_ID
HAVING COUNT(*) > 1;

SELECT *
FROM Shipments
WHERE Delay_Hours IS NULL;

UPDATE Shipments s
JOIN (
    SELECT Route_ID,
           AVG(Delay_Hours) AS AvgDelay
    FROM Shipments
    WHERE Delay_Hours IS NOT NULL
    GROUP BY Route_ID
) r
ON s.Route_ID = r.Route_ID
SET s.Delay_Hours = r.AvgDelay
WHERE s.Delay_Hours IS NULL;

SELECT Shipment_ID,
       Pickup_Date,
       Delivery_Date
FROM Shipments
WHERE Delivery_Date < Pickup_Date;

SELECT o.Order_ID
FROM Orders o
LEFT JOIN Routes r
ON o.Route_ID = r.Route_ID
WHERE r.Route_ID IS NULL;


SELECT o.Order_ID
FROM Orders o
LEFT JOIN Warehouses w
ON o.Warehouse_ID = w.Warehouse_ID
WHERE w.Warehouse_ID IS NULL;

SELECT s.Shipment_ID
FROM Shipments s
LEFT JOIN Orders o
ON s.Order_ID = o.Order_ID
WHERE o.Order_ID IS NULL;

SELECT s.Shipment_ID
FROM Shipments s
LEFT JOIN Delivery_Agents d
ON s.Agent_ID = d.Agent_ID
WHERE d.Agent_ID IS NULL;

-- ============================================
-- TASK 2 : DELIVERY DELAY ANALYSIS
-- ============================================

USE DHL_Logistics;

-- Query 1: Delivery Duration for Each Shipment

SELECT
    Shipment_ID,
    Pickup_Date,
    Delivery_Date,
    TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date) AS Delivery_Duration_Hours
FROM Shipments;

-- Query 2: Top 10 Delayed Routes

SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours),2) AS Avg_Delay_Hours
FROM Shipments
GROUP BY Route_ID
ORDER BY Avg_Delay_Hours DESC
LIMIT 10;

-- Query 3: Rank Shipments by Delay

SELECT
    Shipment_ID,
    Warehouse_ID,
    Delay_Hours,
    RANK() OVER(
        PARTITION BY Warehouse_ID
        ORDER BY Delay_Hours DESC
    ) AS Delay_Rank
FROM Shipments;

-- Query 4: Average Delay by Delivery Type

SELECT
    o.Delivery_Type,
    ROUND(AVG(s.Delay_Hours),2) AS Avg_Delay_Hours
FROM Orders o
JOIN Shipments s
ON o.Order_ID = s.Order_ID
GROUP BY o.Delivery_Type;

-- Query 5: on-time vs delayed shipments

SELECT
    Delivery_Status,
    COUNT(*) AS Total_Shipments
FROM Shipments
GROUP BY Delivery_Status;

-- ============================================
-- TASK 3 : Route Optimization Insights
-- ============================================

-- Query 1: Average Transit Time per Route

SELECT
    Route_ID,
    ROUND(AVG(TIMESTAMPDIFF(HOUR, Pickup_Date, Delivery_Date)),2) AS Avg_Transit_Time_Hours
FROM Shipments
GROUP BY Route_ID
ORDER BY Avg_Transit_Time_Hours DESC;

-- Query 2: Average Delay per Route

SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours),2) AS Avg_Delay_Hours
FROM Shipments
GROUP BY Route_ID
ORDER BY Avg_Delay_Hours DESC;

-- Query 3: Distance-to-Time Efficiency Ratio

SELECT
    Route_ID,
    Distance_KM,
    Avg_Transit_Time_Hours,
    ROUND(Distance_KM / Avg_Transit_Time_Hours,2) AS Efficiency_Ratio
FROM Routes
ORDER BY Efficiency_Ratio ASC;

-- Query 4: Worst 3 Routes by Efficiency Ratio

SELECT
    Route_ID,
    Distance_KM,
    Avg_Transit_Time_Hours,
    ROUND(Distance_KM / Avg_Transit_Time_Hours, 2) AS Efficiency_Ratio
FROM Routes
ORDER BY Efficiency_Ratio ASC
LIMIT 3;


-- Query 5: Routes with More Than 20% Delayed Shipments

SELECT
    s.Route_ID,
    COUNT(*) AS Total_Shipments,
    SUM(
        CASE
            WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
            THEN 1
            ELSE 0
        END
    ) AS Delayed_Shipments,
    ROUND(
        (SUM(
            CASE
                WHEN TIMESTAMPDIFF(HOUR, s.Pickup_Date, s.Delivery_Date) > r.Avg_Transit_Time_Hours
                THEN 1
                ELSE 0
            END
        ) * 100.0) / COUNT(*), 2
    ) AS Delay_Percentage
FROM Shipments s
JOIN Routes r
ON s.Route_ID = r.Route_ID
GROUP BY s.Route_ID
HAVING Delay_Percentage > 20
ORDER BY Delay_Percentage DESC;

-- ============================================
-- TASK 4 : Warehouse Performance
-- ============================================

-- Query 1: Top 3 Warehouses with Highest Average Delay

SELECT
    Warehouse_ID,
    ROUND(AVG(Delay_Hours),2) AS Avg_Delay_Hours
FROM Shipments
GROUP BY Warehouse_ID
ORDER BY Avg_Delay_Hours DESC
LIMIT 3;

-- Task 4 - Query 2
-- Total Shipments vs Delayed Shipments

SELECT
    Warehouse_ID,
    COUNT(*) AS Total_Shipments,
    SUM(CASE
            WHEN Delay_Hours > 0 THEN 1
            ELSE 0
        END) AS Delayed_Shipments
FROM Shipments
GROUP BY Warehouse_ID;


-- Task 4 - Query 3
-- Warehouses Above Global Average Delay

WITH WarehouseDelay AS
(
    SELECT
        Warehouse_ID,
        AVG(Delay_Hours) AS AvgDelay
    FROM Shipments
    GROUP BY Warehouse_ID
),

GlobalDelay AS
(
    SELECT AVG(Delay_Hours) AS GlobalAvg
    FROM Shipments
)

SELECT
    wd.Warehouse_ID,
    ROUND(wd.AvgDelay,2) AS Avg_Delay
FROM WarehouseDelay wd
CROSS JOIN GlobalDelay gd
WHERE wd.AvgDelay > gd.GlobalAvg
ORDER BY wd.AvgDelay DESC;


-- Task 4 - Query 4
-- Warehouse Ranking by On-Time Delivery %

SELECT
    Warehouse_ID,

    ROUND(
        SUM(CASE
                WHEN Delay_Hours = 0 THEN 1
                ELSE 0
            END) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Delivery_Percentage,

    RANK() OVER
    (
        ORDER BY
        ROUND(
            SUM(CASE
                    WHEN Delay_Hours = 0 THEN 1
                    ELSE 0
                END) * 100.0 / COUNT(*),
            2
        ) DESC
    ) AS Warehouse_Rank

FROM Shipments
GROUP BY Warehouse_ID;


-- ============================================
-- TASK 5 : Delivery Agent Performance
-- ============================================


-- Task 5 - Query 1
-- Rank Delivery Agents by On-Time Delivery % (Per Route)

SELECT
    s.Route_ID,
    s.Agent_ID,
    a.Agent_Name,

    ROUND(
        SUM(CASE
                WHEN s.Delay_Hours <= 2 THEN 1
                ELSE 0
            END) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage,

    RANK() OVER (
        PARTITION BY s.Route_ID
        ORDER BY
            SUM(CASE
                    WHEN s.Delay_Hours <= 2 THEN 1
                    ELSE 0
                END) * 100.0 / COUNT(*) DESC
    ) AS Agent_Rank

FROM Shipments s
JOIN Delivery_Agents a
ON s.Agent_ID = a.Agent_ID

GROUP BY
    s.Route_ID,
    s.Agent_ID,
    a.Agent_Name;
    
    
    -- Task 5 - Query 2
-- Agents with On-Time % Below 85%

SELECT
    s.Agent_ID,
    a.Agent_Name,

    ROUND(
        SUM(CASE
                WHEN s.Delay_Hours <= 2 THEN 1
                ELSE 0
            END) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Percentage

FROM Shipments s
JOIN Delivery_Agents a
ON s.Agent_ID = a.Agent_ID

GROUP BY
    s.Agent_ID,
    a.Agent_Name

HAVING On_Time_Percentage < 85

ORDER BY On_Time_Percentage;


-- Task 5 - Query 3

SELECT
    'Top 5 Agents' AS Category,
    ROUND(AVG(Avg_Rating),2) AS Average_Rating,
    ROUND(AVG(Experience_Years),2) AS Average_Experience
FROM
(
    SELECT *
    FROM Delivery_Agents
    ORDER BY Avg_Rating DESC
    LIMIT 5
) TopAgents

UNION ALL

SELECT
    'Bottom 5 Agents',
    ROUND(AVG(Avg_Rating),2),
    ROUND(AVG(Experience_Years),2)
FROM
(
    SELECT *
    FROM Delivery_Agents
    ORDER BY Avg_Rating ASC
    LIMIT 5
) BottomAgents;


-- Additional Analysis: Low-Performing Agents

SELECT
    Agent_ID,
    Agent_Name,
    Experience_Years,
    Avg_Rating
FROM Delivery_Agents
WHERE Avg_Rating < (
    SELECT AVG(Avg_Rating)
    FROM Delivery_Agents
)
ORDER BY Avg_Rating ASC;


-- ============================================
-- TASK 6 : Shipment Tracking Analytics
-- ============================================

-- Task 6 - Query 1
-- Latest Shipment Status

SELECT
    Shipment_ID,
    Delivery_Status,
    MAX(Delivery_Date) AS Latest_Delivery_Date
FROM Shipments
GROUP BY Shipment_ID, Delivery_Status
ORDER BY Latest_Delivery_Date DESC;


-- Task 6 - Query 2
-- Routes with Majority of Shipments In Transit or Returned

SELECT
    Route_ID,
    Delivery_Status,
    COUNT(*) AS Total_Shipments
FROM Shipments
WHERE Delivery_Status IN ('In Transit', 'Returned')
GROUP BY Route_ID, Delivery_Status
ORDER BY Total_Shipments DESC;


-- Task 6 - Query 3
-- Orders with Delay Greater Than 120 Hours

SELECT
    Shipment_ID,
    Order_ID,
    Route_ID,
    Warehouse_ID,
    Delay_Hours
FROM Shipments
WHERE Delay_Hours > 120
ORDER BY Delay_Hours DESC;

-- ============================================
-- TASK 7 : Advanced KPI Reporting
-- ============================================

-- Task 7 - Query 1
-- Average Delivery Delay per Source Country

SELECT
    r.Source_Country,
    ROUND(AVG(s.Delay_Hours),2) AS Avg_Delivery_Delay
FROM Shipments s
JOIN Routes r
ON s.Route_ID = r.Route_ID
GROUP BY r.Source_Country
ORDER BY Avg_Delivery_Delay DESC;


-- Task 7 - Query 2
-- On-Time Delivery Percentage

SELECT
    COUNT(*) AS Total_Deliveries,

    SUM(
        CASE
            WHEN Delay_Hours <= 2 THEN 1
            ELSE 0
        END
    ) AS On_Time_Deliveries,

    ROUND(
        SUM(
            CASE
                WHEN Delay_Hours <= 2 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS On_Time_Delivery_Percentage

FROM Shipments;

-- Task 7 - Query 3
-- Average Delay per Route

SELECT
    Route_ID,
    ROUND(AVG(Delay_Hours),2) AS Average_Delay
FROM Shipments
GROUP BY Route_ID
ORDER BY Average_Delay DESC;


-- Task 7 - Query 4
-- Warehouse Utilization Percentage

SELECT
    w.Warehouse_ID,
    w.City,
    w.Capacity_per_day,

    COUNT(s.Shipment_ID) AS Shipments_Handled,

    ROUND(
        (COUNT(s.Shipment_ID) * 100.0) / w.Capacity_per_day,
        2
    ) AS Warehouse_Utilization_Percentage

FROM Warehouses w

LEFT JOIN Shipments s
ON w.Warehouse_ID = s.Warehouse_ID

GROUP BY
    w.Warehouse_ID,
    w.City,
    w.Capacity_per_day

ORDER BY Warehouse_Utilization_Percentage DESC;


-- Task 7 - Query 5
-- Overall Logistics KPI Summary

SELECT

ROUND(AVG(Delay_Hours),2) AS Average_Delay_Hours,

COUNT(*) AS Total_Shipments,

SUM(CASE
        WHEN Delay_Hours<=2 THEN 1
        ELSE 0
    END) AS On_Time_Shipments,

ROUND(
SUM(CASE
        WHEN Delay_Hours<=2 THEN 1
        ELSE 0
    END)*100/COUNT(*),
2) AS On_Time_Percentage

FROM Shipments;