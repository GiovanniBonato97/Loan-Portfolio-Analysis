# Consumer Loan Portfolio Analysis – SQL

## Business problem
A lender needs to understand its loan portfolio: what customers borrow for, how loans are priced, and where credit risk is concentrated. These insights support lending policy, risk-based pricing and collections planning.

## Data
10,000 consumer loans issued between 2007 and 2015 across 49 US states ($146.8M funded in total). Each row is one loan, with amount, term, interest rate, credit grade, borrower income and state, loan purpose, payments, recoveries and loan status.

## Key findings
- **Pricing follows risk.** Default rates rise from **1.5% in grade A to 18.0% in grade G**, while average interest rates rise from 7.2% to 25.2%.
- **Longer loans are riskier.** 60-month loans default at **6.6% vs 5.0%** for 36-month loans, and carry a higher average rate (16.2% vs 11.9%).
- **Small business loans are the riskiest purpose**, with an **18.4% default rate**, more than three times the portfolio average of 5.4%.
- **High-cost states default more.** Across most loan purposes, borrowers in CA, NY, FL, TX and NJ default more often, for example 6.3% vs 4.6% for debt consolidation loans.
- **Defaults are costly and recoveries are low.** 544 defaulted loans had $8.1M funded and $4.5M unpaid at default, and only **10.4%** of that unpaid balance was recovered.
- **Lending grew fast.** Loans issued in the four largest states (CA, NY, TX, FL) rose 55–79% from 2013 to 2014.

## Recommendations
- Tighten approval criteria or add pricing for small business loans and for grades F–G.
- Monitor 60-month loans and high-cost-state borrowers more closely, since both show higher default rates.
- Review collections, as recoveries cover only about a tenth of the unpaid balance on defaulted loans.

## Questions answered
1. **Portfolio overview:** size, value, years, states and overall default rate
2. **Loan purpose:** portfolio mix, and home improvement, car and medical loans issued in 2015
3. **Loan terms:** 36- vs 60-month loans by year, and their interest and default rates
4. **Interest rates:** 2015 rate range, and interest vs default rate by credit grade
5. **State volumes:** loans per state and growth from 2013 to 2014
6. **Delinquencies and defaults:** problem loans by status, and default and delinquency rates by purpose and state group
7. **Risk ranking and exposure:** top 10 states by default rate, and money lost to defaulted loans

## SQL techniques used
- Views: a `loans` view creates a clean `issue_year` so every query filters by year reliably
- Filtering and aggregation: `WHERE`, `GROUP BY`, `HAVING`, `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`
- Conditional logic: `CASE WHEN`, including inside aggregates to calculate rates
- Common table expressions (`WITH`)
- Window functions: `RANK() OVER` for risk ranking and `SUM() OVER ()` for portfolio share
- String functions: `SUBSTR`, `TRIM`, `LIKE`

## Definitions
- **Default:** `default_flag = 1` (loan status Charged Off or Default)
- **Delinquent:** loan status In Grace Period or Late (16–30 / 31–120 days)

## Tools
SQLite · DB Browser for SQLite

📄 **Report:** [Loan_Portfolio_Analysis_Report (PDF)](Loan_Portfolio_Analysis_Report.pdf)
💻 **Code:** [loan_portfolio_analysis.sql](loan_portfolio_analysis.sql)
📁 **Data:** [bank_loan_data.xls](bank_loan_data.xls)
