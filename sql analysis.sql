select order_date,sum(sales_amount) as total_sales
from [dbo].[sales]
where order_date is not null
group by order_date
order by order_date


select year(order_date) as order_year,sum(sales_amount) as total_sales
from [dbo].[sales]
where order_date is not null
group by year(order_date)
order by year(order_date)


select year(order_date) as order_year,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers, 
sum(quantity) as total_quantities
from [dbo].[sales]
where order_date is not null
group by year(order_date)
order by year(order_date)



select month(order_date) as order_month,
year(order_date) as order_year,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers, 
sum(quantity) as total_quantities
from [dbo].[sales]
where order_date is not null
group by month(order_date),year(order_date)
order by month(order_date),year(order_date)




select DATETRUNC(month,order_date) as order_date,
sum(sales_amount) as total_sales,
count(distinct customer_key) as total_customers, 
sum(quantity) as total_quantities
from [dbo].[sales]
where order_date is not null
group by DATETRUNC(month,order_date)
order by DATETRUNC(month,order_date)

select order_date,total_sales,
sum(total_sales) over (partition by order_date order by order_date) as running_total
from(
select Datetrunc(month,order_date) as order_date ,sum(sales_amount) as total_sales
from [dbo].[sales]
where order_date is not null
group by Datetrunc(month,order_date) 
 ) t

--moving average of price 


select order_date,total_sales,
sum(total_sales) over (order by order_date) as running_total,
avg(avg_price) over (order by order_date) as moving_total_sales
from(
select Datetrunc(month,order_date) as order_date ,
sum(sales_amount) as total_sales,
avg(price) as avg_price
from [dbo].[sales]
where order_date is not null
group by Datetrunc(month,order_date) 
 ) t



 --performance analysis 

 with yearly_product_sales as(
 select sum(f.sales_amount) as current_sales,
 p.product_name,
 year(f.order_date) as order_year
 from [dbo].[sales] f
 left join [dbo].[products] p
 on f.product_key=p.product_key
 where f.order_date is not null
 group by year(f.order_date),p.product_name
 )
 
 select
 order_year,
 product_name,
 current_sales,
 avg(current_sales) over (partition by product_name) as avg_sales,
 current_sales - avg(current_sales) over (partition by product_name) as diff_avg,
 lag(current_sales) over (partition by product_name order by order_year) py_sales,
 current_sales - lag(current_sales) over (partition by product_name order by order_year) as diff_py
 from yearly_product_sales
 order by product_name,order_year; 


 ---part to whole analysis 
 with category_sales as (
 select 
 category,
 sum(sales_amount) as total_sales
 from [dbo].[sales] f
 left join [dbo].[products] p
 on p.product_key=f.product_key
 group by category)

 select category , total_sales,
 sum(total_sales) over () overall_sales,
 concat(round((cast(total_sales as float) / sum(total_sales) over () )*100,2),'%') as percentage_total 
 from category_sales
 order by total_sales desc 



 ---data segmentation 

 with product_segment as (
 select product_key , product_name ,cost,
 case when cost < 100 then 'below 100'
      when cost between 100 and 500 then '100-500'
      when cost between 500 and 1000 then '500-1000'
      else 'above 1000'
 end cost_range 
 from products) 
 
 select cost_range ,
 count(product_key) as total_products
 from product_segment
 group by cost_range
 order by total_products desc


 --group customers into three segment based on their spending behavior 
 --vip: at least 12 months of history and spending more than 5000 euros.
 --regular: at least 12 month of history but spending 5000 euros or less
 --new:lifespan less then 12 months.
 --and find the total number of customers by each group.

 with customer_spending as (
 select 
 c.customer_key , 
 sum(f.sales_amount) as total_sales, 
 min(order_date) as  first_order,
 max(order_date) as  last_order,
 DATEDIFF(month, min(order_date),max(order_date)) as lifespan
 from [dbo].[sales] f
 left join [dbo].[customer] c
 on f.customer_key=c.customer_key
 where order_date is not null
 group by  c.customer_key
 )

 select 
 customer_segment,
 count(customer_key)
 from(
 select
 customer_key,
 case when lifespan >= 12 and total_sales > 5000 then 'vip'
      when lifespan >= 12 and total_sales <= 5000 then 'regular'
      else 'new'
 end customer_segment
 from customer_spending)t
 group by customer_segment


 --build customer report 
 create view dbo.report_customers as 
 with base_query as (
 select 
 f.order_number,
 f.product_key,
 f.order_date,
 f.sales_amount,
 f.quantity,
 c.customer_key,
 c.customer_number,
 concat(c.first_name,' ' , c.last_name) as customer_name,
 datediff(year, c.birthdate, getdate()) age 
 from [dbo].[sales] f
 left join [dbo].[customer] c
 on f.customer_key=c.customer_key
 where order_date is not null)

 , customer_aggregations as (
 select 
        customer_key,
        customer_number,
        customer_name,
        age,
        count(distinct order_number) as total_order,
        sum(sales_amount) as total_sales,
        sum(quantity) as total_quantity,
        count(distinct product_key) as total_products,
        max(order_date) as last_order_date,
        datediff(year, min(order_date), max(order_date)) as lifespan 
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
case 
    when age < 20 then 'under 20'
    when age between 20 and 29 then '20-20'
    when age between 30 and 39 then '30-39'
    when age between 40 and 49 then '40-49'
    else '50 and above'
end as age_group,
case 
    when lifespan >= 12 and total_sales > 5000 then 'vip'
    when lifespan >= 12 and total_sales <= 5000 then 'regular'
    else 'new'
end customer_segment,
last_order_date,
datediff(month,last_order_date, getdate()) as recency,
total_order,
total_sales,
total_quantity,
total_products,
lifespan,
--avo
case when total_order = 0 then 0 
     else total_sales / total_order 
end as avg_order_value,
--compute average monthly spend
case when lifespan = 0 then total_sales
     else total_sales / lifespan 
end as avg_monthly_spend
from customer_aggregations

--build product report 
create view dbo.report_products as 
with base_query as ( 
select 
f.order_number,
p.product_key,
f.sales_amount,
f.order_date,
f.quantity ,
p.product_name,
p.category,
p.subcategory,
p.cost,
f.customer_key
from [dbo].[sales] f
left join [dbo].[products] p 
on p.product_key=f.product_key
where order_date is not null )
, product_aggregations as (
select 
product_key,
product_name,
category,
subcategory,
cost,
datediff(month,min(order_date),max(order_date)) as lifespan,
max(order_date) as last_sale_date,
count(distinct order_number) as total_orders,
count(distinct customer_key) as total_customers,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity ,
round(avg(cast(sales_amount as float)/nullif (quantity,0)),1) as avg_selling_price 
from base_query 
group by 
product_key,
product_name,
category,
subcategory,
cost
)
select 
product_key,
product_name,
category,
subcategory,
cost,
last_sale_date,
datediff(month,last_sale_date, getdate()) as recency_in_months,
case
  when total_sales > 50000 then ' high performer'
  when total_sales >= 10000 then 'mid-range'
  else 'low_performance' 
end as product_segment,
lifespan,
total_orders,
total_sales,
total_quantity,
total_customers,
avg_selling_price,
--aov 
case  
   when total_orders = 0 then 0
   else total_sales/total_orders
end as avg_order_revenue,

--avg monthly revenue
 
 case
   when lifespan = 0 then total_sales
   else total_sales/lifespan 
 end as avg_monthly_revenue 

 from product_aggregations 
   



 

