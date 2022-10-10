USE dannys_diner;

-- 1. What is the total amount each customer spent at the restaurant?
SELECT s.customer_id, SUM(price) as total
FROM sales s 
JOIN menu m ON m.product_id = s.product_id
GROUP BY s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT s.customer_id, COUNT(DISTINCT(order_date)) as times_visited
FROM sales s
GROUP BY s.customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH cte AS(
	SELECT customer_id, order_date, product_name, 
    DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY order_date) as item
    FROM sales s
	JOIN menu m 
    ON s.product_id = m.product_id)
SELECT customer_id, order_date, product_name
FROM cte
WHERE item = 1
GROUP BY customer_id, product_name;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT  m.product_id, m.product_name, COUNT(s.product_id) AS times_ordered
FROM sales s
JOIN menu m 
ON s.product_id = m.product_id
GROUP BY m.product_id, m.product_name 
ORDER BY times_ordered desc;

-- 5. Which item was the most popular for each customer?
WITH cte AS(
	SELECT customer_id, m.product_name, COUNT(s.product_id) AS times_ordered,
		DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY COUNT(customer_id) DESC) AS most_popular
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
    GROUP BY customer_id, s.product_id
    )
SELECT customer_id, product_name, times_ordered
FROM cte
WHERE most_popular = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH cte AS(
	SELECT m.customer_id, order_date, join_date, product_id,
    DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date) as item
    FROM sales s
    JOIN members m 
	ON s.customer_id = m.customer_id
	WHERE order_date >= join_date
	)
SELECT cte.customer_id, cte.join_date, m.product_name, cte.order_date
FROM cte
JOIN menu m 
ON cte.product_id = m.product_id
WHERE item = 1
GROUP BY customer_id;

-- 7. Which item was purchased just before the customer became a member?
WITH cte AS(
	SELECT m.customer_id, order_date, join_date, product_id,
    DENSE_RANK() OVER (PARTITION BY s.customer_id ORDER BY order_date desc) as item
    FROM sales s
    JOIN members m 
	ON s.customer_id = m.customer_id
	WHERE order_date < join_date
	)
SELECT cte.customer_id, cte.join_date, m.product_name, cte.order_date
FROM cte
JOIN menu m 
ON cte.product_id = m.product_id
WHERE item = 1
ORDER BY customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, COUNT(s.product_id) as total_items, SUM(price) as amount_spent
FROM menu m 
JOIN sales s ON m.product_id = s.product_id
JOIN members mem ON mem.customer_id = s.customer_id
WHERE order_date < join_date
GROUP BY s.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH pts AS(
	SELECT *, CASE WHEN product_id = 1 then price * 20
				ELSE price * 10
                END AS points
	FROM menu
    )
SELECT s.customer_id, SUM(pts.points) AS points
FROM pts
JOIN sales s ON pts.product_id = s.product_id
GROUP BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH dates AS(
	SELECT *,
		DATE_ADD(join_date, INTERVAL 6 DAY) AS valid_date,
        LAST_DAY('2021-01-31') AS last_date
	FROM members
    )
SELECT s.customer_id,
	SUM(CASE 
			WHEN m.product_id = 1 THEN m.price * 20
			WHEN s.order_date between d.join_date AND d.valid_date THEN m.price * 20
			ELSE m.price * 10
        END) AS points
FROM dates d
JOIN sales s ON d.customer_id = s.customer_id
JOIN menu m ON m.product_id = s.product_id
WHERE s.order_date < d.last_date
GROUP BY s.customer_id;

-- BONUS Join All The Things: create a table with customer_id, order_date, product_name, price, member(y/n)
SELECT s.customer_id, s.order_date, m.product_name, m.price, 
	CASE WHEN s.order_date >= mm.join_date THEN 'Y'
		WHEN s.order_date < mm.join_date THEN 'N'
        ELSE 'N'
        END AS 'member'
FROM sales s
LEFT JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mm ON s.customer_id = mm.customer_id;

-- BONUS Rank All The Things: ranking of customer products, but doesn't need the ranking for non-member purchases
WITH summary AS(
	SELECT s.customer_id, s.order_date, m.product_name, m.price, 
		CASE WHEN s.order_date >= mm.join_date THEN 'Y'
			WHEN s.order_date < mm.join_date THEN 'N'
			ELSE 'N'
			END AS 'member'
	FROM sales s
	LEFT JOIN menu m ON s.product_id = m.product_id
	LEFT JOIN members mm ON s.customer_id = mm.customer_id
	)
SELECT *,
	CASE WHEN member = 'N' THEN null
    ELSE RANK() OVER (PARTITION BY customer_id, 'member' ORDER BY order_date) 
    END AS ranking
FROM summary;

