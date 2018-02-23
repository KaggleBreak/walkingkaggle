library(reticulate)
use_python("/usr/local/bin/python3")
getwd()
kaggle <- import("kaggle")

kaggle
#search competitions & files
kaggle$api$competitionsList(search = 'taxi')
kaggle$api$competitionListFiles('nyc-taxi-trip-duration')

#download files
kaggle$api$competitionDownloadFiles(competition = 'nyc-taxi-trip-duration', path = './workspace/kwd2018/data/2')


