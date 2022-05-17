#!/usr/bin/env python3
# from IPython.display import display, HTML
from datetime import datetime
import pandas
import json


import argparse
parser = argparse.ArgumentParser(description="Just an example",
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument("-d", "--json-data", help="JSON Data to be parsed", required=True)
parser.add_argument("-i", "--input-file", help="Excel file location for input", default="Abot.xlsx")
parser.add_argument("-o", "--output-file", help="Excel file location for output", default="Abot.xlsx")
parser.add_argument("-b", "--build-id", help="Build ID of the AGW to append on the excel", required=True)
parser.add_argument("-t", "--test-status", help="Test Status of the AGW to append on the excel", required=True)
#parser.add_argument("-k", "--test-status", help="Test Status of the AGW to append on the excel", required=True)


#parser.add_argument("--ignore-existing", action="store_true", help="skip files that exist")
args = parser.parse_args()

config = vars(args)
print(args.json_data)

f = open(args.json_data)
data = json.load(f)

now = datetime.now()
current_time = now.strftime("%d/%m %H:%M:%S")
new_row_name = 'Result : '+ current_time
excel_data_df = pandas.read_excel(args.input_file, sheet_name='WL 5G SA Daily Regression - May')


def Insert_row(row_number, df, row_value):
    start_upper = 0
    end_upper = row_number
    start_lower = row_number
    end_lower = df.shape[0]
    upper_half = [*range(start_upper, end_upper, 1)]
    lower_half = [*range(start_lower, end_lower, 1)]
    lower_half = [x.__add__(1) for x in lower_half]
    index_ = upper_half + lower_half
    df.index = index_
    df.loc[row_number] = row_value
    df = df.sort_index()
    return df

for i in data['feature_summary']['result']['data']:
    columnSeriesObj = excel_data_df.iloc[: , 1]
    ffName = i['featureName']
    if ffName not in columnSeriesObj.values:
        print("F Not Found : " + ffName)
        shape = excel_data_df.shape
        l = [None] * shape[1]
        l[1] = ffName
        row_number = 9
        excel_data_df = Insert_row(row_number, excel_data_df, l)

removeFF = []

columnSeriesObj = excel_data_df.iloc[: , 1]
for i, v in columnSeriesObj.iteritems():
    res = type(v) == str
    if res and ".feature" in v:
        if not any(sd['featureName']== v for sd in data['feature_summary']['result']['data']):
            removeFF.append(v)

for ff in removeFF:
    excel_data_df = excel_data_df[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] != ff]

excel_data_df.insert(loc=2, column=new_row_name, value='')

for i in data['feature_summary']['result']['data']:
    excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == i['featureName'], new_row_name] = i['features']['status']

excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == "SUMMARY", new_row_name] = current_time
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Total', new_row_name] = data['feature_summary']['result']['totalFeatures']['totalFeaturesstatus']['totalFeaturesstatusNumber']
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Count pass %', new_row_name] = data['feature_summary']['result']['totalFeatures']['totalFeaturesstatus']['totalFeaturesstatusPercentage']
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Count Fail %', new_row_name] = data['feature_summary']['result']['totalScenarios']['totalScenariosFailed']['totalScenariosFailedPercentage']
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Count Fail', new_row_name] = data['feature_summary']['result']['totalScenarios']['totalScenariosFailed']['totalScenariosFailedNumber']
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Count pass', new_row_name] = data['feature_summary']['result']['totalScenarios']['totalScenariosPassed']['totalScenariosPassedNumber']
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Build', new_row_name] = args.build_id
excel_data_df.loc[excel_data_df['WL 5G SA Daily Regression through Magma CICD pipeline'] == 'Status', new_row_name] = args.test_status
# excel_data_df.set_option('display.max_columns', None)
# excel_data_df.set_option('display.expand_frame_repr', False)
# excel_data_df.set_option('max_colwidth', -1)
#for removing unnamed columns
excel_data_df = (excel_data_df)
exclude_columns = ['WL 5G SA Daily Regression through Magma CICD pipeline']
columns_dict=dict([(k,None) if not (k in exclude_columns or k.startswith('Result')) else (k,k) for k in excel_data_df.columns])
#columns_dict=dict([(k,None) if not (k in exclude_columns or k.startswith('Result')) else (k,k) for k in styled.data.columns])
#styled=styled.data.rename(columns=columns_dict)
excel_data_df=excel_data_df.rename(columns=columns_dict)
excel_data_df.to_excel(args.output_file, sheet_name='WL 5G SA Daily Regression - May', engine='openpyxl', index=False)
#Don't remove style code  lines
#styled = (excel_data_df.style
 #           .applymap(lambda v: 'background-color: %s' % 'green' if v=='passed' else 'background-color: %s' % 'red' if v=='failed' else ''))
#styled.to_excel(args.output_file, sheet_name='WL 5G SA Daily Regression - May', engine='openpyxl', index=False)

# def even_number_background(cell_value):
#     color = 'darkorange' if val == "pass" else ''
#     return 'background-color: {}'.format(color)
        
# excel_data_df.style.applymap(even_number_background)

# writer = pandas.ExcelWriter(args.output_file)

# excel_data_df.to_excel(writer, sheet_name='WL 5G SA Daily Regression - May', index=False)

# writer.save()
