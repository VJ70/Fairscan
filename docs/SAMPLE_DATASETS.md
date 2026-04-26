# Sample Datasets for Testing

## 1. Hiring (gender bias) — save as sample_hiring.csv
```
gender,experience_years,education,hired
male,5,graduate,1
male,3,postgraduate,1
female,6,graduate,0
male,2,graduate,1
female,4,postgraduate,1
female,5,graduate,0
male,7,postgraduate,1
female,3,graduate,0
```
Target column: hired | Sensitive column: gender

## 2. Lending (income bias) — save as sample_lending.csv
```
income_group,credit_score,loan_amount,approved
high,750,500000,1
high,680,200000,1
middle,700,150000,1
low,720,50000,0
low,690,80000,0
middle,710,100000,1
low,750,40000,0
```
Target column: approved | Sensitive column: income_group

## Public Datasets
- UCI Adult Income: https://archive.ics.uci.edu/ml/datasets/adult
- COMPAS Recidivism: https://github.com/propublica/compas-analysis
