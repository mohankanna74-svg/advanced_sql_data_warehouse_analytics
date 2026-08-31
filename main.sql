------- CHANGE OVER TIME ------------
select datetrunc(month,order_date) as order_year,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null 
group by datetrunc(month,order_date)
order by datetrunc(month,order_date)

------CUMMULATIVE ANALYSIS-----------
select
order_date,
total_Sales,
sum(total_sales)over( order by order_date rows between unbounded preceding and current row)as running_total_sales,
avg(avg_price)over(order by order_date) as moving_avgerage_price
from
(
select datetrunc(year,order_date)as order_date,
sum(sales_amount)as total_sales,
avg(price) as avg_price
from gold.fact_sales
where order_date is not null
group by datetrunc(year,order_date)
)t

---------- PERFORMANCE ANALYSIS ------------
with yearly_product_sales as(
select year(f.order_date) as order_year,p.product_name,sum(f.sales_amount)as current_sales 
from gold.fact_sales f left join gold.dim_products p
on f.product_key=p.product_key
where order_date is not null
group by year(f.order_date),p.product_name 
)
select 
order_year,
product_name,
current_sales,
lag(current_sales) over(partition by product_name order by order_year)as previous_year_sales,
avg(current_sales)over(partition by product_name) avg_sales,
current_sales - avg(current_sales)over(partition by product_name) as diff_avg,
case when current_sales - avg(current_sales)over(partition by product_name) > 0 then 'above average'
when current_sales - avg(current_sales)over(partition by product_name) < 0 then 'below avereage'
else 'average'
end as 'ranking',
current_sales - lag(current_sales) over(partition by product_name order by order_year)as diff_py_sales,
case when current_sales - lag(current_sales) over(partition by product_name order by order_year) > 0 then 'increase'
when current_sales - lag(current_sales) over(partition by product_name order by order_year) < 0 then 'decrease'
else ' no change'
end 'py_cahnge'
from yearly_product_sales
order by product_name,order_year

-----------PART TO WHOLE ANALYSIS------------
 with category_sales as(
 select 
 category,
 sum(sales_amount) as  total_sales
 from gold.fact_sales f left join gold.dim_products p on f.product_key=p.product_key
 group by category
 )
 select category,total_sales,
 sum(total_sales)over() as overall_sales,
 concat(round((cast(total_sales as float)/sum(total_sales)over())*100,2),'%') as percentage_category
 from category_sales
 order by total_sales desc
 
 ---------DATA SEGMENTATION-----------
with segment as(
select 
product_key,product_name,cost,
case when cost < 100 then 'below 100'
when cost between 100 and 500  then '100-500'
when cost between 500 and 1000  then '500-1000'
else 'above 1000'
end as 'cost_range'
from gold.dim_products
)
select cost_range,count(product_key) as  total_products
from segment group by cost_range
order by total_products desc

----------------------------------------------------------------
with customer_spending as (
select c.customer_key,
sum(f.sales_amount)total_spending,
max(f.order_date) as last_buy,
min(f.order_date)as first_buy,
datediff(month,min(order_date),max(order_date))as life_span
from gold.fact_sales f LEFT JOIN gold.dim_customers c
on f.customer_key=c.customer_key group by c.customer_key
)
select customer_segment,
count(customer_key) as total_customers
from(
select 
 customer_key,
case 
when life_span >= 12 and total_spending > 5000 then 'vip'
when life_span  >=12 and total_spending <= 5000 then 'regular customers'
 else 'new'
 end as 'customer_segment'
 from customer_spending
 )t
 group by customer_segment order by total_customers desc
 ----------------------- CUSTOMER REPORT ------------------------------------
 create view gold.report_customers as
 with base_query as(
 select 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity, 
c.customer_key,
c.customer_number,
concat(c.first_name,' ',c.last_name) as customer_name,
datediff(year,c.birthdate,getdate())as age
 from gold.fact_sales f 
 left join gold.dim_customers c
 on f.customer_key=c.customer_key
 where order_date is not null
 )
 ,customer_aggregation as(
 select
 customer_key,
 customer_number,
 customer_name,
 age,
 count(distinct order_number) as total_orders,
 sum(sales_amount)as total_sales,
 sum(quantity)total_quantity,
 count(distinct product_key)as total_products,
 max(order_date)as last_order,
 datediff(month,min(order_date),max(order_date))as life_span
 from base_query
 group by 
  customer_key,
 customer_number,
 customer_name,
 age
 )
  select
 customer_key,
 customer_number,
 customer_name,
 age,
total_orders,
total_sales,
total_quantity,
total_products,
last_order,
life_span,
case when age < 20 then 'under 20'
when age between 20 and 29 then 'btw 20 - 29'
when age between 30 and 39 then 'btw 30- 39'
when age between 40 and 49 then 'btw 40- 49'
else '50 and above'
end as 'age-cateegory',
case 
when life_span >= 12 and total_sales > 5000 then 'vip'
when life_span  >=12 and total_sales <= 5000 then 'regular customers'
 else 'new'
 end as 'customer_segment',
datediff(month,last_order,getdate())as recency,
--------------COMPUATE AVERAGE ORDER VALUE(AVO)------------------------
case when total_sales =0 then 0
else total_sales/total_orders
end as avg_order_values,

------- compute average monthly spends--------
case when life_span = 0 then total_sales
else total_sales/life_span
end as avg_monthly_spend
from customer_aggregation




