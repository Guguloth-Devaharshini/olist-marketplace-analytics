# 🛒 Olist Marketplace Analytics

Olist Marketplace Analytics is a data analytics project based on the **Brazilian Olist E-Commerce dataset**. The project analyzes marketplace data to understand sales, customers, products, sellers, payments, delivery performance, and customer satisfaction.

## 🎯 Project Objective

The objective of this project is to transform raw e-commerce data into meaningful business insights using **Python, SQL, PySpark, and Databricks**.

## 📊 Dataset

The project uses the **Olist Brazilian E-Commerce Public Dataset**, which contains information about orders placed on the Olist marketplace.

The dataset includes multiple CSV files covering different aspects of the marketplace:

* **Customers** – Customer IDs, locations, and customer details
* **Orders** – Order status, purchase date, delivery dates, and estimated delivery
* **Order Items** – Products, sellers, prices, and shipping costs
* **Products** – Product categories and product attributes
* **Sellers** – Seller IDs and seller locations
* **Payments** – Payment methods, installments, and payment values
* **Reviews** – Customer review scores and review comments
* **Geolocation** – Brazilian ZIP-code prefixes and geographical coordinates

These datasets are connected through common IDs such as **customer_id, order_id, product_id, and seller_id**, allowing different tables to be combined for analysis.

## 🛠️ Technologies Used

* Python
* SQL
* PySpark
* Databricks
* Jupyter Notebook
* Data Visualization

## 📂 Repository Structure

```text
olist-marketplace-analytics/
│
├── datasets/
│   └── Olist datasets
│
├── sql/
│   └── SQL analysis queries
│
├── dashboard images and links/
│   └── Dashboard screenshots
│
├── Olist.ipynb
│   └── Python analysis
│
└── README.md
```

## 📈 Key Analysis

The project focuses on:

* Sales and revenue trends
* Customer purchasing behavior
* Product and category performance
* Seller performance
* Delivery and shipping analysis
* Customer review analysis
* Payment method analysis
* Geographic analysis
* Business KPI visualization

## ⚡ Databricks

📓 **Databricks Notebook:**
[Open Olist Analytics Notebook](https://dbc-9e3371f6-cc62.cloud.databricks.com/editor/notebooks/1441092383838716?o=7474651562583956)

📊 **Databricks Dashboard:**
[Open Olist Analytics Dashboard](https://dbc-9e3371f6-cc62.cloud.databricks.com/dashboardsv3/01f18fe255731e3fbb226e770133688f/published?o=7474651562583956)

## 🔄 Project Workflow

```text
Olist Dataset
     ↓
Data Cleaning & Preparation
     ↓
SQL / PySpark Analysis
     ↓
KPI & Business Metrics
     ↓
Data Visualization
     ↓
Databricks Dashboard
     ↓
Business Insights
```

## 💡 Key Business Questions

* Which product categories generate the most revenue?
* What are the monthly sales trends?
* Which sellers and products perform best?
* How does delivery time affect customer reviews?
* Which payment methods are most frequently used?
* Which locations have the highest customer activity?

## 👨‍💻 Author

**Venkata Sai Reddy**

