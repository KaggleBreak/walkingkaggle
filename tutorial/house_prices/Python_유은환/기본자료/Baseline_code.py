import numpy as np
import pandas as pd

train_path = "D:/python_kaggle/train.csv"
test_path = "D:/python_kaggle/test.csv"
output_path = "D:/python_kaggle/summary.csv"

## train preprocessing
raw_train_data = pd.read_csv(train_path)
raw_test_data = pd.read_csv(test_path)

tmp_train_x = raw_train_data.drop('SalePrice',axis=1)
train_y = raw_train_data['SalePrice']

all_data = pd.concat([tmp_train_x, raw_test_data])

categorical = []
numerical = []

for feature in all_data.columns:
    if all_data[feature].dtype == 'object':
        categorical.append(feature)
    else:
        numerical.append(feature)

nu_df = all_data[numerical]
nu_df = nu_df.fillna(0)
ca_df = pd.DataFrame()

for element in categorical:
    ca_df = pd.concat([ca_df,pd.get_dummies(all_data[element])], axis=1)
len(categorical)

new_x = pd.concat([nu_df, ca_df], axis=1)
train_x = new_x.iloc[:1460,:]
test_x = new_x.iloc[1460:,:]

## modeling
from sklearn.linear_model import LinearRegression
lr = LinearRegression().fit(train_x, train_y)
pred = lr.predict(test_x)

np.savetxt(output_path, pred)