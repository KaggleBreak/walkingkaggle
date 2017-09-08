

#Library
library(dplyr)
library(tidyverse)
library(data.table)
library(ggplot2)
library(ggmap)
library(stringr)
library(lubridate)
library(scales)
library(ggthemes)
library(gridExtra)
library(leaflet)
library(sp)
library(geosphere)
library(DT)


data<-fread('C:\\Users\\Eom\\Desktop\\train.csv') #read as data frame

#데이터 전처리 과정

data$id <- as.factor(data$id)
data$vendor_id <- as.factor(data$vendor_id)
store_and_fwd_flag <- as.factor(data$store_and_fwd_flag)


#Convert trip duration in to hours, minutes, and seconds.
data <- data %>%
  mutate(duration_minutes = floor(data$trip_duration / 60),
         duration_seconds = data$trip_duration %% 60)


# convert date/time format into a better format using lubridate package 
# ymd_hms : date time format
data$pickup_datetime = ymd_hms(data$pickup_datetime)
data$dropoff_datetime = ymd_hms(data$dropoff_datetime)
head(data$pickup_datetime)


# split up pickip_datetime into seperate components
data <- data %>%
  mutate(pickup_year = year(data$pickup_datetime),
         pickup_month = month(data$pickup_datetime),
         pickup_day = day(data$pickup_datetime),
         pickup_hour = hour(data$pickup_datetime),
         pickup_minute = minute(data$pickup_datetime),
         pickup_seconds = second(data$pickup_datetime),
         pickup_weekday = weekdays(data$pickup_datetime), 
         pickup_weekday = factor(pickup_weekday, levels = c("월요일","화요일", "수요일", "목요일", "금요일", "토요일", "일요일")))

# split up dropoff_datetime into seperate components
data <- data %>%
  mutate(dropoff_year = year(data$dropoff_datetime),
         dropoff_month = month(data$dropoff_datetime),
         dropoff_day = day(data$dropoff_datetime),
         dropoff_hour = hour(data$dropoff_datetime),
         dropoff_minute = minute(data$dropoff_datetime),
         dropoff_seconds = second(data$dropoff_datetime), 
         dropoff_weekday = weekdays(data$dropoff_datetime), 
         dropoff_weekday = factor(dropoff_weekday, levels = c("월요일","화요일", "수요일", "목요일", "금요일", "토요일", "일요일")))

names(data)[names(data) == 'trip_duration'] <- 'trip_duration_total_in_seconds'





# 20000개의 표본 랜덤추출(승하차 지점 시각화를 위해)
set.seed(450)
sample <- data %>%
  sample_n(20000)


# 승차지점 시각화
leaflet() %>% 
  addProviderTiles("CartoDB.Positron") %>%   addCircleMarkers(data = sample, lng = ~ pickup_longitude, lat = ~ pickup_latitude, radius = 0.1,
                                                              color = "blue")
#하차지점 시각화
leaflet() %>% 
  addProviderTiles("CartoDB.Positron") %>% 
  addCircleMarkers(data = sample, lng = ~ dropoff_longitude, lat = ~ dropoff_latitude, radius = 0.1,
                   color = "red")

#승차지점과 다르게 하차 지점이 강의 서쪽에 몰려 있다. 

memory.size(max=T)
rm(data1)

#월별 탑승 시간 분포
data %>%
  ggplot(aes(x = duration_minutes))+
  facet_grid(.~pickup_month)+  #월별
  geom_histogram(stat = "count") +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(limits = c(0,100)) +
  theme_economist()

#월별 탑승시간 boxplot
plot1_1<-boxplot(duration_minutes~pickup_weekday,data=data,ylim=c(0,100))
plot(plot1_1)

#요일별로 탑승시간에 큰 차이를 보이지는 않는다.





#요일별 탑승한 시간 분포
data %>%
  ggplot(aes(x = duration_minutes))+
  facet_grid(.~pickup_weekday)+ #요일별 
  geom_histogram(stat = "count") +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(limits = c(0,100)) +
  theme_economist()
#토요일의 분포가 상대적으로 더 몰려있다는 것을 볼 수 있다.


#월별 탑승한 횟수
data %>%
  ggplot(aes(x = pickup_day)) +
  facet_wrap(~pickup_month)+
  stat_count() +
  scale_y_continuous(labels = comma) +
  scale_x_continuous(breaks = 1*c(1:31)) +
  theme_economist()
#월별로 날짜마다 차이가 존재함



#요일별로 승차한 시간
data %>%
  ggplot(aes(x = pickup_hour)) +
  stat_count() +
  #facet_grid(.~pickup_weekday)
  facet_wrap(~pickup_weekday)
  scale_y_continuous(labels = comma) +
  scale_x_continuous(breaks = 1*c(0:23)) +
  theme_economist()
#금,토 밤과 일요일 새벽에 평일보다 택시를 많이 이용했다는걸 알 수 있다.
  
  

#요일별 승차한 시간 중간값
Mode <- function(x) {
  ux <- unique(x)
  ux[which.max(tabulate(match(x, ux)))]
}

check_weekdays_pickup <- data %>%
  group_by(pickup_weekday) %>%
  summarize(mode_pickup_hour = Mode(pickup_hour)) %>%
  rename(grouping = pickup_weekday)

ggplot(check_weekdays_pickup, aes(x = grouping, y = mode_pickup_hour)) +
  geom_point(stat = "identity") + 
  xlab("") +
  theme_economist() +
  scale_y_continuous(breaks = 2*c(0:12))
#토요일밤과 일요일 새벽에 택시를 많이 탄것을 볼 수 있다.


