use
[demo];

CREATE TABLE demo.dbo.ORDERS
(
    order_id        INT PRIMARY KEY,
    customer_id     INT,
    order_ts        DATE,
    order_total_usd DECIMAL(5, 2),
    item            VARCHAR(50)
);

-- Table 2: Customers
CREATE TABLE demo.dbo.CUSTOMERS
(
    customer_id   INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email         VARCHAR(100),
    phone_number  VARCHAR(20)
);


-- Table 3: Products
CREATE TABLE demo.dbo.PRODUCTS
(
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100),
    unit_price   DECIMAL(8, 2)
);


-- Table 4: OrderDetails
CREATE TABLE demo.dbo.ORDER_DETAILS
(
    order_detail_id INT PRIMARY KEY,
    order_id        INT,
    product_id      INT,
    quantity        INT,
    total_price     DECIMAL(8, 2),
    FOREIGN KEY (order_id) REFERENCES demo.dbo.ORDERS (order_id),
    FOREIGN KEY (product_id) REFERENCES demo.dbo.PRODUCTS (product_id)
);


-- Table 5: PaymentMethods
CREATE TABLE demo.dbo.PAYMENT_METHODS
(
    payment_method_id   INT PRIMARY KEY,
    payment_method_name VARCHAR(50)
);


-- Table 6: OrderPayments
CREATE TABLE demo.dbo.ORDER_PAYMENTS
(
    order_payment_id  INT PRIMARY KEY,
    order_id          INT,
    payment_method_id INT,
    payment_amount    DECIMAL(8, 2),
    payment_date      DATE,
    FOREIGN KEY (order_id) REFERENCES demo.dbo.ORDERS (order_id),
    FOREIGN KEY (payment_method_id) REFERENCES demo.dbo.PAYMENT_METHODS (payment_method_id)
);


-- Table 7: ShippingMethods
CREATE TABLE demo.dbo.SHIPPING_METHODS
(
    shipping_method_id   INT PRIMARY KEY,
    shipping_method_name VARCHAR(50)
);


-- Table 8: OrderShipments
CREATE TABLE demo.dbo.ORDER_SHIPMENTS
(
    order_shipment_id  INT PRIMARY KEY,
    order_id           INT,
    shipping_method_id INT,
    shipment_date      DATE,
    tracking_number    VARCHAR(20),
    FOREIGN KEY (order_id) REFERENCES demo.dbo.ORDERS (order_id),
    FOREIGN KEY (shipping_method_id) REFERENCES demo.dbo.SHIPPING_METHODS (shipping_method_id)
);


-- Table 9: OrderStatus
CREATE TABLE demo.dbo.ORDER_STATUS
(
    order_status_id INT PRIMARY KEY,
    order_id        INT,
    status_name     VARCHAR(50),
    status_date     DATE,
    FOREIGN KEY (order_id) REFERENCES demo.dbo.ORDERS (order_id)
);


-- Table 10: Coupons
CREATE TABLE demo.dbo.COUPONS
(
    coupon_id           INT PRIMARY KEY,
    coupon_code         VARCHAR(20),
    discount_percentage DECIMAL(5, 2)
);


-- Table 11: OrderCoupons
CREATE TABLE demo.dbo.ORDER_COUPONS
(
    order_coupon_id INT PRIMARY KEY,
    order_id        INT,
    coupon_id       INT,
    FOREIGN KEY (order_id) REFERENCES demo.dbo.ORDERS (order_id),
    FOREIGN KEY (coupon_id) REFERENCES demo.dbo.COUPONS (coupon_id)
);


DECLARE
@tableName NVARCHAR(100)
DECLARE
tableCursor CURSOR FOR
SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' OPEN tableCursor
FETCH NEXT
FROM tableCursor
INTO @tableName
    WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE
@sql NVARCHAR(MAX)
    SET @sql = 'EXEC sys.sp_cdc_enable_table 
                    @source_schema = N''dbo'',
                    @source_name = N''' + @tableName + ''',
                    @role_name = NULL,
                    @supports_net_changes = 0;'

    EXEC sp_executesql @sql

    FETCH NEXT FROM tableCursor INTO @tableName
END

CLOSE tableCursor DEALLOCATE tableCursor


-- At this point you should get a row returned from this query
SELECT s.name AS Schema_Name, tb.name AS Table_Name, tb.object_id, tb.type, tb.type_desc, tb.is_tracked_by_cdc
FROM sys.tables tb
         INNER JOIN sys.schemas s on s.schema_id = tb.schema_id
WHERE tb.is_tracked_by_cdc = 1
    
