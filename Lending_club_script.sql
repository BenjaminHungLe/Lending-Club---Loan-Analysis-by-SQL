-- Create Credit_customers SCHEMA and Import lending_club_2007_2011.csv

USE credit_customers;

### I. DATA WRANGLING

-- Create [issue_year]column - year of issue_d to use later
ALTER TABLE lending_club_2007_2011  
	ADD COLUMN issue_year INT AS (YEAR(STR_TO_DATE(issue_d, '%b-%Y'))) AFTER issue_d; 
    
-- Create [credit_opened_year]column - the year when customers opened their credit line to use later
UPDATE lending_club_2007_2011
	SET earliest_cr_line = DATE_FORMAT(STR_TO_DATE(earliest_cr_line, '%b-%Y'), '%b-%Y'); 

ALTER TABLE lending_club_2007_2011  
	ADD COLUMN credit_opened_year INT AS (YEAR(STR_TO_DATE(earliest_cr_line, '%b-%Y'))) AFTER earliest_cr_line; 

### FILL empty cells by "NULL" value in EXCEL before import to MySQL because MySQL will skip rows which have empty cells.


### START TO DROP UNNECCESSARY COLUMNS OR COLUMNS HAVE SAME VALUE ACROSS THE ROWS
-- [funded_amnt_inv]column belongs [funded_amnt], therefore we can drop it later.
-- [out_prncp]column & [out_prncp_inv]column can be dropped because all rows have "0" value
-- can drop [policy_code]column
-- can drop [acc_now_delinq]column because all rows have "0" value
-- can drop [hardship_flag]column because all rows have "N" value
-- can drop [tax_liens]column because all rows have "0" and "NULL" value
-- can drop [delinq_amnt]column because all rows have "0" value
-- can drop [disbursement_method]column because all borrowers received money by "Cash"
-- can drop [pymnt_plan]column because all rows have "n" value
-- can drop [initial_list_status] because all rows have "f" value
-- can drop [collections_12_mths_ex_med] because all rows have "0" value
-- can drop [application_type]column because all rows have "Individual" value

ALTER TABLE lending_club_2007_2011
	DROP COLUMN policy_code,
    DROP COLUMN acc_now_delinq,
    DROP COLUMN hardship_flag,
    DROP COLUMN tax_liens,
    DROP COLUMN delinq_amnt,
    DROP COLUMN disbursement_method,
    DROP COLUMN pymnt_plan,
    DROP COLUMN initial_list_status,
    DROP COLUMN collections_12_mths_ex_med,
    DROP COLUMN out_prncp,
    DROP COLUMN out_prncp_inv,
    DROP COLUMN application_type;

### CHECK DUPLICATE ROWS
-- Concat columns value to 1 value and compare to find if there is any duplicate values

### CREATE PRIMARY KEY COLUMNS BY CONCAT VALUES FROM DIFFERENT COLUMNS. COULD BE [ZipCode] + [credit_opened_year] + [subgrade] + [purpose] + [loan_amnt]
### CHECK DUPLICATE ROWS

SELECT tb1.primkey
FROM (	SELECT *, 
		CONCAT(LEFT(zip_code,3),"-",
        DATE_FORMAT(STR_TO_DATE(earliest_cr_line, '%b-%Y'), '%m%y'),"-",
        LEFT(home_ownership,1),"-",
        sub_grade,"-",
        UPPER(LEFT(purpose,3)),"-", 
        CONVERT(ROUND(dti,0),char),"-", 
        CONVERT(funded_amnt,char),"-",
        DATE_FORMAT(STR_TO_DATE(issue_d, '%b-%Y'), '%m%y')) as primkey
        FROM lending_club_2007_2011
	) tb1
GROUP BY tb1.primkey
HAVING COUNT(tb1.primkey)>1;
-- -> There is no duplicate column. Then we will create index column.
ALTER TABLE lending_club_2007_2011 
	ADD loan_id INT NOT NULL AUTO_INCREMENT PRIMARY KEY ;

ALTER TABLE lending_club_2007_2011 
	MODIFY loan_id INT FIRST;

-- Drop more column : [emp_title]column, [zipcode] column
ALTER TABLE lending_club_2007_2011
	DROP COLUMN emp_title,
	DROP COLUMN zip_code;

### II. ANALYZE DATA

## 1) OVERALL ANALYSIS
-- What is the maximum and minimum amount of personal loans? 
SELECT DISTINCT loan_amnt as top_5_max_amount_for_personal_loans
FROM lending_club_2007_2011
ORDER BY loan_amnt DESC
LIMIT 5 ;

SELECT DISTINCT loan_amnt as top_5_min_amount_for_personal_loans
FROM lending_club_2007_2011
ORDER BY loan_amnt 
LIMIT 5 ;

-- What is the largest funded amount?
SELECT MAX(funded_amnt) as max_funded_amount
FROM lending_club_2007_2011;

-- What is the lowest interest rate?
SELECT grade, MIN(int_rate) as lowest_int_rate
FROM lending_club_2007_2011
GROUP BY grade
ORDER BY grade;

-- Loan amount funded YOY analysis
SELECT issue_year,
		FORMAT(total_amount_funded, '#,#'),
        FORMAT(LAG(total_amount_funded) OVER(ORDER BY issue_year), '#,#') as amount_funded_last_year,
        ROUND(total_amount_funded / LAG(total_amount_funded) OVER(ORDER BY issue_year) * 100 ,2) as growth_percent
FROM (
		SELECT distinct issue_year,
		SUM(funded_amnt) OVER(PARTITION BY issue_year) as total_amount_funded
		FROM lending_club_2007_2011
		ORDER BY issue_year
        ) tb1;

-- See sum of money inquiries and money funded every year
SELECT issue_year,
	COUNT(loan_id) as total_loans,
	FORMAT(SUM(loan_amnt), '#,#') as money_inquiries,
	FORMAT(SUM(funded_amnt), '#,#') as money_funded,
    FORMAT(SUM(funded_amnt_inv), '#,#') as money_funded_by_investor,
    ROUND(SUM(funded_amnt)/SUM(loan_amnt) * 100,2) as percent_money_funded 
FROM lending_club_2007_2011
GROUP BY issue_year
ORDER BY issue_year;        
        
-- -> We can see that the number of loans and the amount of funded loans raised rapidly from 2007 to 2011. There was an explosive growth in 2008 which increased 8.6 times in number of loans and 8 times in the amount of money funded.
-- -> The year 2009 had the highest percentage of money funded to money applied for loans. 
-- -> We could consider The Great Recession that occurred from late 2007 to 2009 had an attritue to LC's rapid growth.

## 2) ANALYZE BY TERMS

-- Count number of loans
SELECT term,
		COUNT(loan_id) as total_loans
FROM lending_club_2007_2011
GROUP BY term;

-- Count number of fully paid and charged-off loans.
SELECT term, loan_status,
		COUNT(loan_id) as total_loans
FROM lending_club_2007_2011
GROUP BY loan_status, term
ORDER BY term, loan_status;

-- Average interest rate of terms
SELECT term,
		loan_status,
		ROUND(AVG(int_rate),2) as avg_int_rate
FROM lending_club_2007_2011
GROUP BY term, loan_status
ORDER BY term, loan_status;

-- See how much money has been inquirired and funded
SELECT term 
	,  FORMAT(SUM(loan_amnt), '#,#') as money_inquiries
	,  FORMAT(SUM(funded_amnt), '#,#') as money_funded
    ,  FORMAT(SUM(funded_amnt_inv), '#,#') as money_funded_by_investor
    , ROUND(SUM(funded_amnt)/SUM(loan_amnt) * 100,2) as percent_money_funded 
FROM lending_club_2007_2011
GROUP BY term;

-- Paid-off rate base on term.
SELECT distinct term, 
		loan_status,
		COUNT(loan_id) OVER(PARTITION BY term) as total_loans,
        ROUND(COUNT(loan_id) OVER(PARTITION BY loan_status, term)/ COUNT(loan_id) OVER(PARTITION BY term) * 100,2) as paid_off_rate
FROM lending_club_2007_2011
LIMIT 2
OFFSET 2;
-- -> The paid-off rate of 60-month loans is just only approximately 76% while 36-month loans has 88.37% rate.


## 3) ANALYZE BY GRADE

-- Number of loans of each grade and -- Which grade has the most loans?
SELECT DISTINCT grade,
		COUNT(loan_id) as total_loans,
		FORMAT(SUM(loan_amnt), '#,#') as money_inquiries,
		FORMAT(SUM(funded_amnt), '#,#') as money_funded,
		FORMAT(SUM(funded_amnt_inv), '#,#') as money_funded_by_investor,
		ROUND(SUM(funded_amnt)/SUM(loan_amnt) * 100,2) as percent_money_funded 
FROM lending_club_2007_2011
GROUP BY grade
ORDER BY grade;

-- Paid off rate based on grades
SELECT DISTINCT grade, loan_status,
		COUNT(loan_id) OVER(PARTITION BY grade) as total_loans,
		ROUND(COUNT(loan_id) OVER(PARTITION BY grade, loan_status) / COUNT(loan_id) OVER(PARTITION BY grade) * 100,2) as paid_off_rate
FROM lending_club_2007_2011
ORDER BY loan_status DESC, grade
LIMIT 7;
-- -> We can see that the paid-off rate decreased along with the the credibility of grades. The highest grade, grade A, has the highest paid-off rate, 93.76%, and vice versa, grade D only has 64.15% of paid-off rate.

-- Average annual income of each grade
SELECT DISTINCT grade,
        FORMAT(ROUND(AVG(annual_inc) OVER (PARTITION BY grade),2), '#,#') as average_income
FROM lending_club_2007_2011;
-- -> Suprisingly, it looks like that people who have the highest credibility scores have the lowest average income. And people in the lowsest grade have the highest average income. 

## 4) ANALYZE BY YEAR
-- See sum of money inquiries and money funded every year
SELECT issue_year,
	COUNT(loan_id) as total_loans,
	FORMAT(SUM(loan_amnt), '#,#') as money_inquiries,
	FORMAT(SUM(funded_amnt), '#,#') as money_funded,
    FORMAT(SUM(funded_amnt_inv), '#,#') as money_funded_by_investor,
    ROUND(SUM(funded_amnt)/SUM(loan_amnt) * 100,2) as percent_money_funded 
FROM lending_club_2007_2011
GROUP BY issue_year
ORDER BY issue_year;
-- -> We can see that the number of loans and the amount of loans raised rapidly from 2007 to 2008. There was an explosive growth in 2008 which increased 8.6 times in number of loans and 8 times in the amount of money funded.
-- -> The year 2009 had the highest percentage of money funded to money applied for loans. 
-- -> We could consider The Great Recession that occurred from late 2007 to 2009 had an attritue to LC's rapid growth.

-- Which year has the highest interest rate and the info of the loan?
SELECT *
FROM lending_club_2007_2011
ORDER BY int_rate DESC
LIMIT 1;
-- -> The highest interest rate loan is 24.4% - came from the 60-month loan of $12,000 in June 2011 whose customer is from New York, G-grade, renting, $35.8k income and has 12.98% of Debt-to-Income ratio 

### 5) CUSTOMER ANALYSIS
## 5.1. ANALYZE BY STATE
-- Total number of loans, amount of loans, and amount of funded money loans
SELECT addr_state as State,
	COUNT(loan_id) as total_loans,
		FORMAT(SUM(loan_amnt), '#,#') as money_inquiries,
		FORMAT(SUM(funded_amnt), '#,#') as money_funded,
		FORMAT(SUM(funded_amnt_inv), '#,#') as money_funded_by_investor,
		ROUND(SUM(funded_amnt)/SUM(loan_amnt) * 100,2) as percent_money_funded 
FROM lending_club_2007_2011
GROUP BY addr_state
ORDER BY money_funded DESC;
-- -> All of 6 states have similar percentage of money funded which is approximately 97%. New York has the most money funded for loans, 42 million dollars, and Illinois has the lowest, 17 million dollars.

-- Average interest rate of States and by loan_status
SELECT DISTINCT addr_state as State,
		loan_status,
        ROUND(AVG(int_rate)  OVER (PARTITION BY addr_state),2) as state_avg_int_rate,
        ROUND(AVG(int_rate)  OVER (PARTITION BY loan_status, addr_state),2) as avg_int_rate
FROM lending_club_2007_2011
ORDER BY state_avg_int_rate, addr_state;
-- -> New York has the highest average interest rate which is 12.24% while Texas has the average interest rate of charged-off loans - 14.36%

-- Average annual income of States and Which State has the lowest median annual income?
SELECT addr_state as State,
		FORMAT(ROUND(AVG(annual_inc)), '#,#') as lowest_median_income
FROM lending_club_2007_2011
GROUP BY addr_state
ORDER BY lowest_median_income;
-- -> Florida has the lowest median annual income borrowers

## 5.2. ANALYZE BY INCOME
SELECT DISTINCT group_of_income,
		loan_status,
        COUNT(loan_id) OVER(PARTITION BY group_of_income) as total_loans,
		ROUND(COUNT(loan_id) OVER(PARTITION BY group_of_income, loan_status)/ COUNT(loan_id) OVER(PARTITION BY group_of_income) * 100,2) as percent_to_total_loans
FROM (
    SELECT loan_id, 
			loan_status,
			annual_inc,
			CASE
				WHEN annual_inc <= 30000 THEN 'Under $30K'
				WHEN annual_inc > 30000 AND annual_inc <= 50000 THEN 'From $30K - $50K'
                WHEN annual_inc > 50000 AND annual_inc <= 80000 THEN 'From $50K - $80K'
				WHEN annual_inc > 80000 AND annual_inc <= 160000 THEN 'From $80K - $160K'
				WHEN annual_inc > 160000 AND annual_inc <= 360000 THEN 'From $165K - $360K'
				ELSE 'Higher than $360k'
			END AS group_of_income
	FROM lending_club_2007_2011
    ) tb1
ORDER BY total_loans DESC;
-- -> The group of borrowers who have income from $50,000 to $80,000 are has the highest number of loans: approximately 6,800 loans. And people have income higher than $360,000 has the least: only 63 loans.

## 5.3. ANALYZE BY Purpose
-- Count number of loans of each purpose
SELECT DISTINCT purpose,	
		COUNT(loan_id) OVER (PARTITION BY purpose) as number_of_loans
FROM lending_club_2007_2011
ORDER BY number_of_loans DESC;
-- -> The most number of loans are for debt consolidation with approximately 9,400 loans. -- other has different values of title match others purposes.

-- Calculate average amount of money of loans and average interest rate
SELECT DISTINCT purpose,
		FORMAT(ROUND(AVG(funded_amnt) OVER(PARTITION BY purpose),2), '#,#') as avg_amount_of_money_funded,
        ROUND(AVG(int_rate) OVER(PARTITION BY purpose),2) as avg_int_rate
FROM lending_club_2007_2011
ORDER BY avg_int_rate DESC;
-- ->Loans for small business have the higest average interest rate (13.18%) as well as average amount of funded money (~ $13,000). While vacation loans has the lowest funded money - (~$6,000) and lowest interest rate (10.60%)

-- Calculate the paid-off rate and charged-off rate of each purpose
SELECT DISTINCT purpose,
		loan_status,
		COUNT(loan_id) OVER(PARTITION BY purpose, loan_status) as number_of_loans,
        COUNT(loan_id) OVER(PARTITION BY purpose) as total_loans,
        ROUND(COUNT(loan_id) OVER(PARTITION BY purpose, loan_status) /  COUNT(loan_id) OVER(PARTITION BY purpose) *100 , 2) as percentage
FROM lending_club_2007_2011
ORDER BY loan_status, percentage DESC;
-- -> Small business loans has the highest charged-off rate which is 27.2%. And wedding is the purpose of having lowest charge-off rate - 10.6%

## ANALYZE BY DEMOGRAPHIC
-- by home ownership, dti, years from open credit line to loan LC, total opening acc

-- Calculate number of loans and average interest rate of each type home ownership
SELECT DISTINCT home_ownership,
		COUNT(loan_id) OVER (PARTITION BY home_ownership) as number_of_loans,
        ROUND(COUNT(loan_id) OVER (PARTITION BY home_ownership)/ COUNT(*)  OVER() *100, 2) as percentage_to_total_loans,
        ROUND(AVG(int_rate)  OVER (PARTITION BY home_ownership) ,2) as avg_int_rate
FROM lending_club_2007_2011;
-- -> People who are renting are the major of customers of Lending Club service. They take 55.1% of number of loans. Home owners are only 7.77% of loans while people paying mortgage take 36.9% number of total loans.
-- -> People who are renting also have the higher average interest rate than others which is 12.32%

-- See grade, dti, paid-off
-- See State and percentage of Home owner 
SELECT * 
FROM (SELECT DISTINCT addr_state,
		home_ownership,
        COUNT(loan_id) OVER (PARTITION BY addr_state) as total_loans,
		COUNT(loan_id) OVER (PARTITION BY addr_state, home_ownership) as number_of_loans,
        ROUND(COUNT(loan_id) OVER (PARTITION BY addr_state, home_ownership) / COUNT(loan_id) OVER(PARTITION BY addr_state) *100,2) as percentage
		FROM lending_club_2007_2011) tb1
WHERE home_ownership = 'OWN'
ORDER BY percentage DESC;
-- -> Texas has the highest percentage of house owning in loans - 9.62%. While California has the highest number of loans but only 5.7% of loans is home owners which also the lowest rate.
-- ORDER BY loan_status, percentage DESC;

-- Calculate charged-off rate based on home_ownership
SELECT DISTINCT home_ownership,
		loan_status,
		COUNT(loan_id) OVER (PARTITION BY loan_status, home_ownership) as number_of_loans,
        ROUND(COUNT(loan_id) OVER (PARTITION BY loan_status, home_ownership) / COUNT(loan_id) OVER(PARTITION BY home_ownership) *100,2) as percentage
FROM lending_club_2007_2011
ORDER BY loan_status, percentage DESC;
-- -> Except customer who have 'OTHER' status for home owning which is only 44 loans, customers who own house have the highest charged-off rate which is 15.85%.

## 5.5. ANALYZE BY CREDIT HISTORY
-- deliquency, public record, how long from the last deliquency, deliquencies in 2 year, loan times in last 6 months, bankrupt, debt_settlement_flag, total_acc and open_acc (open_acc belongs to total_acc)
SELECT loan_id,
		loan_status,
		delinq_2yrs,
        pub_rec,
        mths_since_last_delinq,
        inq_last_6mths,
        debt_settlement_flag,
        total_acc
FROM lending_club_2007_2011
WHERE loan_status = 'Charged Off';

## 5.6. ANALYZE REVENUE
-- Calculate Revenue and Profit
SELECT FORMAT(SUM(funded_amnt), '#,#') as Loans,
		FORMAT(SUM(total_pymnt), '#,#') as Revenue,
        FORMAT(SUM(total_pymnt) - SUM(funded_amnt), '#,#') as Profit
FROM lending_club_2007_2011;
-- -> Total Profit from 2007 to 2011 is $24.31 million dollars

-- Calculate Revenue and Profit every year
SELECT DISTINCT issue_year as 'year',
		FORMAT(SUM(funded_amnt), '#,#') as Loans,
		FORMAT(SUM(total_pymnt), '#,#') as Revenue,
        FORMAT(SUM(total_pymnt) - SUM(funded_amnt) - SUM(collection_recovery_fee), '#,#') as Profit
FROM lending_club_2007_2011
GROUP BY issue_year;
-- -> Year 2007 recorded the negative profit which was minus ~ $40,000 dollar. However, LC was established in 2006, only 2 years, this loss was still acceptable. 
-- -> In 2008, LC recored positive profit, ~ $259K dollars. Their profit kept increasing years later, 6.8 times higher in 2009 (~ $1.76 million) and 27 times higher in 2010 (~ $7.01 million)
-- -> 2011 recored the first year LC had profits exceeded $10 million dollars.

-- Analyze revenue from customers paid full term.
SELECT COUNT(loan_id) as numbers_of_loan,
		FORMAT(SUM(funded_amnt), '#,#') as Loans,
        FORMAT(SUM(term * installment), '#,#') as supposed_revenue,
        FORMAT(SUM(total_pymnt), '#,#') as payment,
        FORMAT(SUM(total_rec_prncp), '#,#') as principal,
        FORMAT(SUM(total_rec_int), '#,#') as interests,
        FORMAT(SUM(total_rec_late_fee), '#,#') as late_fee
FROM	
    (SELECT *,
			TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-',issue_d), '%d-%b-%Y'), STR_TO_DATE(CONCAT('01-',last_pymnt_d), '%d-%b-%Y')) as months_made_payment
	FROM lending_club_2007_2011) tb1
WHERE term + 1 = months_made_payment AND loan_status = 'Fully Paid';
-- -> There were 3260 loans that customers paid full term payments. Earned profit was approximately $7.1 million.

-- Analyze revenue from customers fully paid before expired.
SELECT COUNT(loan_id) as numbers_of_loan,
		FORMAT(SUM(funded_amnt), '#,#') as Loans,
        FORMAT(SUM(term * installment), '#,#') as supposed_revenue,
        FORMAT(SUM(total_pymnt), '#,#') as payment,
        FORMAT(SUM(total_rec_prncp), '#,#') as principal,
        FORMAT(SUM(total_rec_int), '#,#') as interests,
        FORMAT(SUM(total_rec_late_fee), '#,#') as late_fee
FROM	
    (SELECT *,
			TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-',issue_d), '%d-%b-%Y'), STR_TO_DATE(CONCAT('01-',last_pymnt_d), '%d-%b-%Y')) as months_made_payment
	FROM lending_club_2007_2011) tb1
WHERE term + 1 > months_made_payment AND loan_status = 'Fully Paid';
-- -> There were 13,505 loans that customers paid before the expired month of loan. This helped customers save money from interests. LC earned ~ $31 million for profit from those loans.

-- Calculate charge-off, loss money from default
SELECT *,
	TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-',issue_d), '%d-%b-%Y'), STR_TO_DATE(CONCAT('01-',last_pymnt_d), '%d-%b-%Y')) as months_made_payment
FROM lending_club_2007_2011 
WHERE TIMESTAMPDIFF(MONTH, STR_TO_DATE(CONCAT('01-',issue_d), '%d-%b-%Y'), STR_TO_DATE(CONCAT('01-',last_pymnt_d), '%d-%b-%Y')) < 3;

-- Calculate loss money from charged-off loans which were took back enough money (which included principal and interests)
SELECT *
FROM lending_club_2007_2011
WHERE loan_status = 'Charged Off' AND total_pymnt > funded_amnt
LIMIT 10;
-- -> There were 406 loans get charged off but LC took back enough money of loans (which included principal and interests)

--  Calculate number of charged-off loans but did not pay off completely. 
SELECT COUNT(loan_id)
FROM lending_club_2007_2011
WHERE loan_status = 'Charged Off' AND total_pymnt < funded_amnt;

-- -> There were 2536 loans get default, in which 11 loans didn't pay any single payment.

-- Calculate money earned from charged-off loans which paid enough 
SELECT 	number_of_loans,
		Loans_amount,
		Payment,
        Profit
FROM	
    (SELECT COUNT(loan_id) as number_of_loans,
			FORMAT(SUM(funded_amnt), '#,#') as Loans_amount,
			FORMAT(SUM(term * installment), '#,#') as Supposed_Revenue,
			FORMAT(SUM(total_pymnt), '#,#') as Payment,
			FORMAT(SUM(total_rec_prncp), '#,#') as Principal,
			FORMAT(SUM(total_rec_int), '#,#') as Interests,
			FORMAT(SUM(total_rec_late_fee), '#,#') as Late_fee,
			FORMAT(SUM(recoveries), '#,#') as Recoveries,
			FORMAT(SUM(collection_recovery_fee), '#,#') as Recoveries_fee,
            FORMAT(SUM(total_pymnt) - SUM(funded_amnt), '#,#') as Profit
	FROM lending_club_2007_2011
	WHERE loan_status = 'Charged Off' and total_pymnt >= funded_amnt) tb1;
-- -> There were 407 loans get charged off but LC took back enough money to pay back for lenders and investors. These loans just only made $885K in profit while it was supposed to earn more than $2 million profit if borrowers paid full term.

-- Calculate loss money from customers did not pay once
SELECT 	number_of_loans,
		Loans_amount,
		Payment,
        Profit
FROM	
    (SELECT COUNT(loan_id) as number_of_loans,
			FORMAT(SUM(funded_amnt), '#,#') as Loans_amount,
			FORMAT(SUM(term * installment), '#,#') as Supposed_Revenue,
			FORMAT(SUM(total_pymnt), '#,#') as Payment,
			FORMAT(SUM(total_rec_prncp), '#,#') as Principal,
			FORMAT(SUM(total_rec_int), '#,#') as Interests,
			FORMAT(SUM(total_rec_late_fee), '#,#') as Late_fee,
			FORMAT(SUM(recoveries), '#,#') as Recoveries,
			FORMAT(SUM(collection_recovery_fee), '#,#') as Recoveries_fee,
            FORMAT(SUM(total_pymnt) - SUM(funded_amnt), '#,#') as Profit
	FROM lending_club_2007_2011
	WHERE loan_status = 'Charged Off' and total_pymnt = 0) tb1;
-- -> There were 11 loans which borrowers didn't pay once that caused $106K lost.

--  Calculate number of charged-off loans but did not pay off enough money to cover principal. 
SELECT 	number_of_loans,
		Loans_amount,
		Payment,
        Profit
FROM	
    (SELECT COUNT(loan_id) as number_of_loans,
			FORMAT(SUM(funded_amnt), '#,#') as Loans_amount,
			FORMAT(SUM(term * installment), '#,#') as Supposed_Revenue,
			FORMAT(SUM(total_pymnt), '#,#') as Payment,
			FORMAT(SUM(total_rec_prncp), '#,#') as Principal,
			FORMAT(SUM(total_rec_int), '#,#') as Interests,
			FORMAT(SUM(total_rec_late_fee), '#,#') as Late_fee,
			FORMAT(SUM(recoveries), '#,#') as Recoveries,
			FORMAT(SUM(collection_recovery_fee), '#,#') as Recoveries_fee,
            FORMAT(SUM(total_pymnt) - SUM(funded_amnt) - SUM(collection_recovery_fee), '#,#') as Profit
	FROM lending_club_2007_2011
	WHERE loan_status = 'Charged Off' AND total_pymnt < funded_amnt) tb1;  
-- -> There were 2536 loans which valued ~ $29.84 million dollars that borrowers get charged off and caused ~ $15.43 million dollars loss in profit. 
-- -> There was a big difference between supposed revenue and actual revenue of Charged-off loans. It would be ~ $27 million difference if all the borrowers paid their loans full term. 
-- -> However, not everyone would pay full term.

-- #Calcualte profit, loss from grade and purpose.
-- Loss on charged-off loans based on purpose
SELECT DISTINCT purpose,
		COUNT(loan_id) OVER(PARTITION BY purpose) as number_of_loans,
		FORMAT(SUM(funded_amnt) OVER(PARTITION BY purpose), '#,#') as Loans_amount,
		FORMAT(SUM(term * installment) OVER(PARTITION BY purpose), '#,#') as Supposed_Revenue,
		FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose), '#,#') as Payment,
		FORMAT(SUM(total_rec_prncp) OVER(PARTITION BY purpose), '#,#') as Principal,
		FORMAT(SUM(total_rec_int) OVER(PARTITION BY purpose), '#,#') as Interests,
		FORMAT(SUM(total_rec_late_fee) OVER(PARTITION BY purpose), '#,#') as Late_fee,
		FORMAT(SUM(recoveries) OVER(PARTITION BY purpose), '#,#') as Recoveries,
		FORMAT(SUM(collection_recovery_fee) OVER(PARTITION BY purpose), '#,#') as Recoveries_fee,
        FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose), '#,#') as Profit,
		FORMAT(ROUND((SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose))/(COUNT(loan_id) OVER(PARTITION BY purpose)),2), '#,#') as avg_loss_per_loan
FROM lending_club_2007_2011
WHERE loan_status = 'Charged Off'
ORDER BY avg_loss_per_loan DESC;
-- -> Debt consolidation loans caused highest loss which is ~ $7.66 million dollars for 1449 loans. Meanwhile, small-business loans had the highest loss for each charged-off loans which was $6,865 dollar lost per loan.

-- Profit on Paid-off loans based on purpose
SELECT DISTINCT purpose,
		COUNT(loan_id) OVER(PARTITION BY purpose) as number_of_loans,
		FORMAT(SUM(funded_amnt) OVER(PARTITION BY purpose), '#,#') as Loans_amount,
		FORMAT(SUM(term * installment) OVER(PARTITION BY purpose), '#,#') as Supposed_Revenue,
		FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose), '#,#') as Payment,
		FORMAT(SUM(total_rec_prncp) OVER(PARTITION BY purpose), '#,#') as Principal,
		FORMAT(SUM(total_rec_int) OVER(PARTITION BY purpose), '#,#') as Interests,
		FORMAT(SUM(total_rec_late_fee) OVER(PARTITION BY purpose), '#,#') as Late_fee,
        FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose), '#,#') as Profit,
		FORMAT(ROUND((SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose))/(COUNT(loan_id) OVER(PARTITION BY purpose)),2), '#,#') as avg_profit_per_loan
FROM lending_club_2007_2011
WHERE loan_status = 'Fully Paid'
ORDER BY avg_profit_per_loan DESC;
-- -> Small business loans brought the most average profit per loan with ~ $3K/loan while vacation loan had the lowest average profit per loan with ~ $900.
-- -> Debt consolidation loans made the most profit for LC which were ~ $21.17 million dollars for 7940 Paid-Off loans.

## 5.7. DISTRIBUTION OF PAY-OFF AND CHARGE-OFF RATE
SELECT DISTINCT	loan_status,
		purpose,
        ROUND(COUNT(loan_id) OVER (PARTITION BY loan_status, purpose)/ COUNT(loan_id) OVER (PARTITION BY loan_status) * 100,2) as percent_of_purpose_in_status, 
        ROUND(COUNT(loan_id) OVER (PARTITION BY purpose)/ COUNT(loan_id) OVER () * 100,2) as percent_of_purpose_in_total_loans
FROM lending_club_2007_2011
ORDER BY loan_status;
-- -> 49.24% of charged off loans came from 'deb_consolidation' purpose, it is because deb_consolidation loans took 47.16% of total loans.
-- -> The sencond highest rate was 'other' purpose which was 10.94% and also took 10.35% of total loans.

SELECT DISTINCT purpose,
		COUNT(loan_id) OVER(PARTITION BY purpose) as number_of_loans,
		FORMAT(SUM(funded_amnt) OVER(PARTITION BY purpose), '#,#') as Loans_amount,
		FORMAT(SUM(term * installment) OVER(PARTITION BY purpose), '#,#') as Supposed_Revenue,
		FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose), '#,#') as Payment,
		FORMAT(SUM(total_rec_prncp) OVER(PARTITION BY purpose), '#,#') as Principal,
		FORMAT(SUM(total_rec_int) OVER(PARTITION BY purpose), '#,#') as Interests,
		FORMAT(SUM(total_rec_late_fee) OVER(PARTITION BY purpose), '#,#') as Late_fee,
        FORMAT(SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose), '#,#') as Profit,
		FORMAT(ROUND((SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose))/(COUNT(loan_id) OVER(PARTITION BY purpose)),2), '#,#') as avg_profit_per_loan
FROM lending_club_2007_2011
ORDER BY avg_profit_per_loan DESC;
-- -> However, when we combined all status, the amount of profit and average profit per loan went down dramatically. Debt consolidation loans dropped profit from $3k to only $1,439 which is more than 50%.
-- -> Debt consolidation total profit dropped from ~ $21.17 million dollars to ~13.51 million dollars.

-- # Calculate the difference of profit that caused by loss from charged-off loans.
WITH tb1 
	AS (SELECT DISTINCT purpose,
				ROUND(SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose),2) as total_profit_all_status,
				ROUND((SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose))/(COUNT(loan_id) OVER(PARTITION BY purpose)),2) as avg_profit_per_loan_all_status
				FROM lending_club_2007_2011),
tb2
    AS (SELECT DISTINCT purpose,
				ROUND(SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose),2) as total_profit,
				ROUND((SUM(total_pymnt) OVER(PARTITION BY purpose) - SUM(funded_amnt) OVER(PARTITION BY purpose) - SUM(collection_recovery_fee) OVER(PARTITION BY purpose))/(COUNT(loan_id) OVER(PARTITION BY purpose)),2) as avg_profit_per_loan
				FROM lending_club_2007_2011
				WHERE loan_status = 'Fully Paid')
SELECT tb1.purpose,
		FORMAT(total_profit_all_status, '#,#') as total_profit_all_status,
        FORMAT(avg_profit_per_loan_all_status, '#,#') as avg_profit_per_loan_all_status,
        FORMAT(total_profit, '#,#') as total_profit_of_fully_paid_loans,
        FORMAT(avg_profit_per_loan, '#,#') as avg_profit_per_loan_of_fully_paid_loans,
		ROUND(((total_profit - total_profit_all_status)/total_profit)*100,2) as difference_percent_in_profit,
        ROUND(((avg_profit_per_loan - avg_profit_per_loan_all_status)/avg_profit_per_loan)*100,2) as difference_percent_in_avg_profit_per_loan
FROM tb1
JOIN tb2 ON tb1.purpose = tb2.purpose;

## 6) ANALYZE RISK OF DEFAULT FOR DIFFERENT PRODUCT TYPES OR CUSTOMER SEGMENT.

-- Frist way: divide charged off loans to different segments based on range of funded amount (1. Under $10k. 2. From $10K - $20K. 3. From $20K - 30K. 4. More than $30K.)
-- -- in charged off segment, list most grade get charged off, avg interest rate, avg installment and avg dti and percent of people have house get charged off. => compare, if loan_id has those attributes more than avg, how many got charged off?

WITH CTE 
	AS (SELECT *,
        ROUND(COUNT(loan_id) OVER (PARTITION BY range_of_loan, loan_status)/COUNT(loan_id) OVER (PARTITION BY range_of_loan) * 100,2) as percentage_of_status,
        COUNT(loan_id) OVER (PARTITION BY range_of_loan) as total_loans
		FROM (
				SELECT *,
					CASE
						WHEN funded_amnt <= 5000 THEN 'Less than $5K'
						WHEN funded_amnt > 5000 AND funded_amnt <= 10000 THEN 'From $5K - $10K'
						WHEN funded_amnt > 10000 AND funded_amnt <= 15000 THEN 'From $10K - $15K'
						WHEN funded_amnt > 15000 AND funded_amnt <= 20000 THEN 'From $15K - $20K' 
						WHEN funded_amnt > 20000 AND funded_amnt <= 25000 THEN 'From $20K - $25K'
						WHEN funded_amnt > 25000 AND funded_amnt <= 30000 THEN 'From $25K - $30K'
						ELSE 'More than $30K'
					END as range_of_loan
				FROM lending_club_2007_2011
                ) tb1
		)    
SELECT DISTINCT cte.range_of_loan,
		cte.total_loans,
		cte.loan_status,
        cte.percentage_of_status,
        tb6.grade as most_grade_charged_off,
        tb6.percent_of_grade_in_CO_in_range_of_loan as percent_of_the_most_grade_get_CO,
        tb6.average_int_rate,
        tb6.average_dti,
        tb6.average_installment,
        hometb3.percentage_of_home_ownership_status as percent_house_owner_get_CO
FROM CTE
JOIN 
(SELECT * 
FROM ( SELECT *,
		ROW_NUMBER() OVER(PARTITION BY range_of_loan, loan_status ORDER BY grade_counts DESC) as grade_ranking
        FROM (
				SELECT distinct range_of_loan,
						loan_status,
						grade,
                        COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status, grade) as grade_counts,
						ROUND(COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status, grade)/ COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status) * 100,2) as percent_of_grade_in_CO_in_range_of_loan,
						ROUND(AVG(int_rate) OVER (PARTITION BY range_of_loan, loan_status),2) as average_int_rate,
                        ROUND(AVG(dti) OVER(PARTITION BY range_of_loan, loan_status),2) as average_dti,
                        ROUND(AVG(installment) OVER(PARTITION BY range_of_loan, loan_status),2) as average_installment
				FROM (
					SELECT *,
						CASE
							WHEN funded_amnt <= 5000 THEN 'Less than $5K'
							WHEN funded_amnt > 5000 AND funded_amnt <= 10000 THEN 'From $5K - $10K'
							WHEN funded_amnt > 10000 AND funded_amnt <= 15000 THEN 'From $10K - $15K'
							WHEN funded_amnt > 15000 AND funded_amnt <= 20000 THEN 'From $15K - $20K' 
							WHEN funded_amnt > 20000 AND funded_amnt <= 25000 THEN 'From $20K - $25K'
							WHEN funded_amnt > 25000 AND funded_amnt <= 30000 THEN 'From $25K - $30K'
							ELSE 'More than $30K'
						END as range_of_loan
					FROM lending_club_2007_2011) tb3
				WHERE loan_status = 'Charged Off') tb4
            ) tb5
WHERE grade_ranking = 1
ORDER BY range_of_loan) tb6
ON tb6.range_of_loan = cte.range_of_loan AND tb6.loan_status = cte.loan_status
JOIN
	(SELECT *
	FROM (SELECT Distinct range_of_loan,
			loan_status,
			home_ownership,
			COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status, home_ownership) as home_ownership_counts,
			ROUND(COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status, home_ownership)/ COUNT(loan_id) OVER(PARTITION BY range_of_loan, loan_status) * 100,2) as percentage_of_home_ownership_status
			FROM 
					(SELECT *,
									CASE
										WHEN funded_amnt <= 5000 THEN 'Less than $5K'
										WHEN funded_amnt > 5000 AND funded_amnt <= 10000 THEN 'From $5K - $10K'
										WHEN funded_amnt > 10000 AND funded_amnt <= 15000 THEN 'From $10K - $15K'
										WHEN funded_amnt > 15000 AND funded_amnt <= 20000 THEN 'From $15K - $20K' 
										WHEN funded_amnt > 20000 AND funded_amnt <= 25000 THEN 'From $20K - $25K'
										WHEN funded_amnt > 25000 AND funded_amnt <= 30000 THEN 'From $25K - $30K'
										ELSE 'More than $30K'
									END as range_of_loan
								FROM lending_club_2007_2011) hometb1) hometb2
		WHERE hometb2.home_ownership = 'OWN' AND hometb2.loan_status = 'Charged Off') hometb3
ON cte.range_of_loan = hometb3.range_of_loan AND cte.loan_status = hometb3.loan_status
ORDER BY funded_amnt;

-- Second way: analyze based on  purpose and term and interest rate.
SELECT *
FROM (
	SELECT DISTINCT purpose,
		term,
        COUNT(loan_id) OVER (PARTITION BY purpose, term) as term_counts,
		loan_status,
		ROUND(COUNT(loan_id) OVER (PARTITION BY purpose, term, loan_status)/ COUNT(loan_id) OVER (PARTITION BY purpose, term) * 100,2) as percent_of_status,
        ROUND(AVG(int_rate) OVER (PARTITION BY purpose, term, loan_status),2) as average_int_rate
		FROM lending_club_2007_2011) tb1
WHERE tb1.loan_status = 'Charged Off';
-- -> We can see 13 of 14 purposes that 60-month loans have the percent of charged off higher than 36-month loans, mostly at least ~2 times higher, except Moving and Small_business. 
-- -> Small business is the only purpuse that both term has more than 23% of loans get charged off.
-- -> All purpose loans has average of interest rate of 60-month loans higher than 36-month loans.

SELECT *
FROM (
	SELECT DISTINCT purpose,
		term,
        COUNT(loan_id) OVER (PARTITION BY purpose, term) as term_counts,
		loan_status,
		ROUND(COUNT(loan_id) OVER (PARTITION BY purpose, term, loan_status)/ COUNT(loan_id) OVER (PARTITION BY purpose, term) * 100,2) as percent_of_status,
        ROUND(AVG(int_rate) OVER (PARTITION BY purpose, term, loan_status),2) as average_int_rate
		FROM lending_club_2007_2011 
        WHERE funded_amnt > 5000 AND funded_amnt <= 10000) tb1
WHERE tb1.loan_status = 'Charged Off';

SELECT distinct loan_status,
		COUNT(loan_id) OVER (PARTITION BY loan_status)
FROM lending_club_2007_2011
WHERE funded_amnt > 5000 AND funded_amnt <= 10000 AND int_rate > 15.14 AND purpose = 'small_business' and term = '60 months';

-- => export queries results to tables and use excel to visualize