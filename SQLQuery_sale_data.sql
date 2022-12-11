--Inspect the data
Select * from dbo.Sales$
Select * from dbo.Customer$
Select * from dbo.Product$

--Checking data type
Select 
	TABLE_NAME
	,COLUMN_NAME
	,DATA_TYPE
From information_schema.columns


--Alter the data type of column
Alter table dbo.Sales$
Alter column "Order Date" date
Alter table dbo.Sales$
Alter column "Ship Date" date
Alter table dbo.Sales$
Alter column Profit float
Alter table dbo.Sales$
Alter column Sales float
Alter table dbo.Sales$
Alter column Quantity int


--Analyzing the data
--1. Shipping mode analytics
--a. Maximum, minimum and average shipping date
With tbl as
	(
	Select 
		Distinct "Order ID"
		,Datediff(day, "Order Date", "Ship Date") as daydiff
	From dbo.Sales$
	)
Select 
	Max(daydiff) as max_delivery_time
	,Min(daydiff) as min_delivery_time
	,Round(Avg(Cast(daydiff as float)),2) as avg_delivery_time
From tbl
/* The maximum delivery time is 7 days, minimum delivery time is 0 day and the average delivery time is 3.96 days*/



--b. The average delivery time for each city and state
With tbl1 as 
	(
	Select 
		Distinct "Order ID"
		,Datediff(day, "Order Date", "Ship Date") as daydiff
		,State
		,City
	From dbo.Sales$
	)
Select 
	State
	,City
	,Round(Avg(cast(daydiff as float)), 2) as avg_delivery_time
From tbl1
Group by Rollup(State, City)



--c. Count the number of each shipping mode and calculate the percentage
With tbl2 as 
	(
	Select 
		Distinct "Order ID"
		,"Ship Mode"
	From dbo.Sales$
	)
Select 
	"Ship Mode"
	,Count(*) as count_ship_mode
	,Round(Cast(Count(*) as float) / (Select Count(*) from tbl2) * 100, 2) as percent_ship_mode 
From tbl2
Group by "Ship Mode"


/*d. Categorize the delivery time into 3 segments “One time”, “Early” and “Late”. 
	 Count the number of orders by each segment. Calculate the percentage of each segment*/
With tbl3 as
	(
	Select
		Distinct "Order ID"
		,"Order Date"
		,"Ship Date"
		,Datediff(day, "Order Date", "Ship Date") as delivery_time
		,"Ship Mode"
		,Case 
			When Datediff(day, "Order Date", "Ship Date") = 0 and "Ship Mode" = 'Same Day' then 'On Time'
			When Datediff(day, "Order Date", "Ship Date") > 0 and "Ship Mode" = 'Same Day' then 'Late'
			When Datediff(day, "Order Date", "Ship Date") < 1 and "Ship Mode" = 'First Class' then 'Early'
			When Datediff(day, "Order Date", "Ship Date") = 1 and "Ship Mode" = 'First Class' then 'On Time'
			When Datediff(day, "Order Date", "Ship Date") > 1 and "Ship Mode" = 'First Class' then 'Late'
			When Datediff(day, "Order Date", "Ship Date") < 3 and "Ship Mode" = 'Second Class' then 'Early'
			When Datediff(day, "Order Date", "Ship Date") = 3 and "Ship Mode" = 'Second Class' then 'On Time'
			When Datediff(day, "Order Date", "Ship Date") > 3 and "Ship Mode" = 'Second Class' then 'Late'
			When Datediff(day, "Order Date", "Ship Date") < 6 and "Ship Mode" = 'Standard Class' then 'Early'
			When Datediff(day, "Order Date", "Ship Date") = 6 and "Ship Mode" = 'Standard Class' then 'On Time'
			Else 'Late'
			End as shipping_status
	From dbo.Sales$
	),

tbl4 as 
	(
	Select 
		shipping_status
		,Count(*) as count_shipping_status
		,Round(Cast(Count(*) as float) / (Select Count(*) from tbl3) * 100, 2) as shipping_status_percent
	From tbl3
	Group by shipping_status
	)

--e. Count the number of order that are late-delivery over time. Calculate the percentage of those results 

Select
	Year("Order Date") as year
	,shipping_status
	,Count(*) as count_shipping_status
	,Round(Cast(Count(*) as float) / Cast(Sum(count(*)) Over(Partition by Year("Order Date")) as float) * 100, 2) as percent_shipping_status
From tbl3 
Group by Year("Order Date"), shipping_status
Order by 2, 1


--Customer analysis
--a. Find out the customer that order most
Select 
	c."Customer Name"
	,Count(Distinct s."Order Id") as count_order
From dbo.Customer$ as c
Inner Join dbo.Sales$ as s
On c."Customer ID" = s."Customer ID"
Group by c."Customer Name"
Order by 2 desc

--b. Find out the segment of customer that order most
Select 
	c.Segment
	,Count(Distinct s."Order ID") as count_order
From dbo.Customer$ as c
Inner Join dbo.Sales$ as s
On c."Customer ID" = s."Customer ID"
Group by c.Segment
Order by 2 desc

--c. Count the number of customer by geographical location
Select	
	State
	,Count(Distinct "Customer ID") as count_customer
From dbo.Sales$
Group by State
Order by 2 desc

--d. Conduct the RFM analysis. Count and calculate the perentage of each segment
With summarize as 
(
	Select
		Customer$."Customer Name",
		Avg(Sales$.Profit) as avg_profit,
		Count(Sales$."Order ID") as frequency,
		Max(Sales$."Order Date") as most_recent_order,
		Datediff(DD, Max(Sales$."Order Date"),(Select Max(Sales$."Order Date") from Sales$)) as recency
	From Sales$
	Inner Join Customer$
	On Sales$."Customer ID"=Customer$."Customer ID"
	Group by Customer$."Customer Name"
),
RFM as
(
	Select 
		*,
		Ntile(4) Over(Order by recency) as recency_index,
		NTILE(4) Over(Order by frequency) as frequency_index,
		NTILE(4) Over(Order by avg_profit) as monetary_index
	From summarize
),
category as
	(
	Select 
		RFM.*,
		CONCAT(recency_index,frequency_index,monetary_index) as concat_rfm,
		Case	
			When Concat(recency_index,frequency_index,monetary_index) in ('444','344') then 'Loyal'
			When Concat(recency_index,frequency_index,monetary_index) in ('442','441','431','433','432','423','342','341','333','323') then 'Potential'
			When Concat(recency_index,frequency_index,monetary_index) in ('422','421','412','411','311') then 'New customer'
			When Concat(recency_index,frequency_index,monetary_index) in ('424','413','414','314','313') then 'Promising'
			When Concat(recency_index,frequency_index,monetary_index) in ('443','434','343','334','324') then 'Need Attention'
			When Concat(recency_index,frequency_index,monetary_index) in ('144','214','114','113') then 'Cannot Lose'
			When Concat(recency_index,frequency_index,monetary_index) in ('331','321','312','221','213') then 'About to sleep'
			When Concat(recency_index,frequency_index,monetary_index) in ('244','243','242','234','224','143','142','134','133','124') then 'At risk'
			When Concat(recency_index,frequency_index,monetary_index) in ('332','322','231','241','233','232','223','222','132','123','122','212','211') then 'Hibernating'
			When Concat(recency_index,frequency_index,monetary_index) in ('111','112','121','131','141') then 'Lost'
			End as segment
	From RFM
	)
Select 
	segment
	,Count(*) as count_segment
	,Round(Cast(Count(*) as float) / (Select Count(*) from category) * 100, 2) as percent_segment
From category
Group by segment
Order by 3 desc

--Sale analysis
--a. Examine the month over month revenue growth
With tbl5 as 
	(
	Select 
		Year("Order Date") as year
		,Month("Order Date") as month
		,Round(Sum(Sales), 2) as total_sale
	From dbo.Sales$
	Group by rollup (Year("Order Date"), Month("Order Date"))
	)
Select 
	year
	,month
	,total_sale
	,Lag(total_sale) Over(partition by year Order by month) as previous_month_sale
	,Round((total_sale - Lag(total_sale) Over(partition by year Order by month))/Lag(total_sale) Over(partition by year Order by month)*100, 2) as MoM_sale_growth
From tbl5
Where 
	year is not null and
	month is not null	

--b. Examine the month over month profit growth
With tbl5 as 
	(
	Select 
		Year("Order Date") as year
		,Month("Order Date") as month
		,Round(Sum(Profit), 2) as total_profit
	From dbo.Sales$
	Group by rollup (Year("Order Date"), Month("Order Date"))
	)
Select 
	year
	,month
	,total_profit
	,Lag(total_profit) Over(Partition by year Order by month) as previous_month_profit
	,Round((total_profit - Lag(total_profit) Over(Partition by year Order by month))/Lag(total_profit) Over(Partition by year Order by month)*100, 2) as MoM_profit_growth
From tbl5
Where 
	year is not null and
	month is not null	

--c. Calculate the total revenue and profit by category product
Select 
	p.Category
	,Round(Sum(s.Sales), 2) as total_revenue
	,Round(Sum(s.Profit), 2) as total_profit
	,Round(Round(Sum(s.Profit), 2) / Round(Sum(s.Sales), 2) * 100, 2) as profit_margin
From dbo.Product$ as p
Inner Join dbo.Sales$ as s
On p."Product ID" = s."Product ID"
Group by p.Category

--d. Examine the top 3 best-seller products (profit criteria first then quantity). Drill down to year
Select 
	*
From 
	(
	Select 
		Year("Order Date") as year
		,p."Product Name"
		,Sum("Quantity") as quantity
		,Sum("Profit") as total_profit
		,Row_number() Over(Partition by Year("Order Date") Order by Sum("Profit") desc) as rank
	From dbo.Sales$ as s
	Inner Join dbo.Product$ as p
	On s."Product ID" = p."Product ID"
	Group by Year("Order Date"), p."Product Name"
	) as rank_tbl
Where rank in (1, 2, 3)


--e. Examine the revenue and profit by state
Select 
	State
	,Round(Sum(Sales), 2) as total_sale
	,Round(Sum(Profit), 2) as total_profit
From dbo.Sales$
Group by State
Order by 2 desc

--Negative profit orders diagnostic analysis
--a. Count the number of orders having negative profits. Calculate the rate
With tbl6 as
	(
	Select 
		"Order ID"
		,Sum(Profit) as total_profit
	From dbo.Sales$
	Group by "Order ID"
	)
Select
	Count(*) as count_negative_profit_order
	,Sum(total_profit) as total_negative_profit
	,Round(Cast(Count(*) as float) / (Select Count(distinct "Order ID") from dbo.Sales$) * 100, 2) as percentage_order
	,Round(Abs(Sum(total_profit)) / (Select Sum(Profit) from dbo.Sales$) * 100, 2) as percentage_over_profit
From tbl6
Where total_profit < 0

--b. Find out the products having most negative orders

Select 
	p."Product Name"
	,Count(*) as count_order
	,Sum(Profit) as total_profit_negative
From dbo.Sales$ as s
Inner Join dbo.Product$ as p
On s."Product ID" = p."Product ID"
Group by p."Product Name"
Order by 3 

