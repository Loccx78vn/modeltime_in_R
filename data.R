---
  title: "Auto Machine Learning in R"
subtitle: "Việt Nam, 2024"
categories: ["SupplyChainManagement", "Forecasting","Machine Learning"]
description: "Đây là bài viết của tôi về cách sử dụng R trong việc dự đoán dữ liệu trong tương lai"
author: "Cao Xuân Lộc"
date: "2024-09-07"
bibliography: references.bib
format: 
  html:
  code-fold: true
code-tools: true
number-sections: true
---
  
  # Giới thiệu:
  
  Ở bài viết này, chúng ta sẽ tiếp tục với đề tài phân tích dữ liệu thời gian trong Quản lí chuỗi cung ứng.

Lý do mình tiếp tục với chủ đề này là vì ở bài viết trước phần xây dựng mô hình Machine Learning với R vẫn chưa tốt, hoặc làm mình chưa cảm thấy đã 😅😅 . Các bạn nào chưa đọc hoặc muốn xem lại topic trước thì có thể ấn vào đây [Time series model](https://loccx78vn.github.io/Forecasting_time_series/).

Vì vậy, ở bài viết này, mình sẽ tập trung vào xây dựng mô hình Machine Learning để đưa ra dự báo tốt hơn. Ngoài ra, mình cũng giới thiệu hai packages trong R có khả năng xử lí tốt dữ liệu thời gian mà không tốn nhiều công sức, đó là package `timetk` và **modeltime.h2o** .

## Chuẩn bị dữ liệu:

Đầu tiên, vẫn là thao tác quen thuộc trong R, chúng ta sẽ tải dữ liệu và các packages cần thiết vào.

```{r}
#Call packages:
pacman::p_load(rio,
               here,
               janitor,
               tidyverse,
               dplyr,
               magrittr,
               lubridate,
               stringr,
               timetk,
               parsnip)
```

::: callout-tip
## Tải thư viện:

Nếu các bạn chưa có các packages này, bạn có thể tải xuống từ CRAN R bằng cú pháp: \``` install.packages(*"name_of_package"*)` ``
:::
  
  ```{r}
#| echo: false
#Import file:
product_demand<-import("C:\\Users\\locca\\Downloads\\Historical Product Demand.csv")
```

Dữ liệu này mình lấy từ trên mạng của **Frank Corrigan**.
Bạn có thể ấn vào nút tải phía dưới này để tải dữ liệu về thực hành.

```{r}
#| warning: false
#| message: false
#| echo: false
library(downloadthis)
product_demand %>%
  download_this(
    output_name = "product_demand",
    output_extension = ".csv",
    button_label = "Download data",
    button_type = "warning",
    has_icon = TRUE,
    icon = "fa fa-save"
  )
```

Nếu bạn gặp khó khăn trong việc xử lí dữ liệu gốc, bạn có thể kham khảo code dưới đây về việc xử lí dữ liệu  dưới đây để tiết kiệm thời gian.

```{r}
#| warning: false
#| message: false
#Change to suitable class (I change the name dataset to product_demand to shortly write)
product_demand <-product_demand %>% 
  mutate(Date = as.Date(Date,format = "%Y/%m/%d"),
         Product_Category = as.factor(Product_Category))

product_demand$Order_Demand <- 
  gsub("[(]", "-", product_demand$Order_Demand)
product_demand$Order_Demand <- 
  gsub("[)]", "", product_demand$Order_Demand)
product_demand$Order_Demand <- 
  as.numeric(product_demand$Order_Demand)

#Then I will create a lot of cols contain year, month, week data and just select from 2012 to 2016:
product_demand <-product_demand %>%
  mutate(Month = month(Date),
         Year = year(Date),
         Week_day = wday(Date)) %>% 
  filter(Year %in% c(2016:2012) & Order_Demand > 0) 


#So I will calculate the total order demand divided by year and month:
daily_df<-product_demand %>% 
  group_by(Warehouse,Date) %>%   
  summarise(daily_demand = round(sum(Order_Demand,
                                     na.rm = T))) %>% 
  ungroup()
```

Và sau khi đã chuẩn bị đầy đủ dữ liệu đầu vào, chúng ta sẽ qua phần thực hành trong R

# Phân tích dữ liệu bằng {timetk}

## Thông tin:

Package `timetk` là một package nằm trong hệ sinh thái `modeltime` để phân tích và dự báo chuỗi thời gian. Mình đã từng thử nhiều *package* về dữ liệu chuỗi thời gian trong R và nhận ra `timetk` cho kết quả dự báo rất rộng và giúp người dùng tránh mất nhiều thời gian để tìm hiểu,.
Gói `timetk` trong R được thiết kế cho phân tích và trực quan hóa chuỗi thời gian. Nó cung cấp nhiều công cụ cho:
  
  - **Chuẩn bị dữ liệu**: Dễ dàng chuyển đổi các khung dữ liệu thành đối tượng chuỗi thời gian và xử lý các định dạng ngày giờ khác nhau.

- **Kỹ thuật tính năng**: Tạo ra các tính năng dựa trên thời gian như giá trị trễ, thống kê lăn, và chỉ báo mùa vụ.

- **Trực quan hóa**: Tạo ra các hình ảnh thông tin về dữ liệu chuỗi thời gian với các hàm đơn giản để vẽ các xu hướng và mẫu mùa vụ.

- **Mô hình hóa**: Tích hợp mượt mà với các gói khác như `dplyr` và `tidyverse`, giúp dễ dàng xây dựng và đánh giá các mô hình chuỗi thời gian.

Tóm lại, `timetk` giúp đơn giản hóa quá trình làm việc với dữ liệu chuỗi thời gian, nâng cao khả năng phân tích và trực quan hóa.


```{=html}
<div style="text-align: center; margin-bottom: 20px;">
  <img src="img/model.png" style="max-width: 100%; height: auto; display: block; margin: 0 auto;">
  
  <!-- Picture Name -->
  <div style="text-align: left; margin-top: 10px;">
  Hình 1: Tổng quan về package timetk
</div>
  
  <!-- Source Link -->
  <div style="text-align: right; font-style: italic; margin-top: 5px;">
  Source: <a href="https://www.business-science.io/code-tools/2021/04/08/autoregressive-machine-learning.html" target="_blank">Link to Image</a>
  </div>
  </div>
  ```

Package `timetk` có trong CRAN, bạn có thể tải xuống thông qua cú pháp `install.packages("timetk")`. Thông tin thêm, bạn có thể theo dõi post của [@mattdancho]

## Thực hành trong R:

Ở bài trước, bạn có thể thấy để hiển thị dữ liệu dạng thời gian trong R thì ta cần phải chuyển đổi dữ liệu sang class `zoo` hoặc `xts` rồi mới dùng package **dygraphs** để hiển thị dữ liệu.

Trong `timetk`, ta không cần chuyển đổi mà chỉ cần dữ liệu ở dạng bảng là có thể tạo được biểu đồ. Ngoài ra, bạn hoàn toàn dễ dàng tạo theo nhóm bằng cách thêm hàm `group_by()` ở trước.

::: callout-tip
## Thêm sự tương tác:

Hàm `plot_time_series()` sẽ hiển thị dữ liệu dạng đường line như các biểu đồ thông thường.

Bạn có thể thêm đối số `.interactive = TRUE` để người dùng tương tác dưới dạng HTML
:::
  
  ## Chuẩn bị dữ liệu:
  
  Như biểu đồ dưới đây, ta có thể đánh giá rằng:
  
  -   Nhà kho A: nhu cầu đặt hàng của khách ở mức thấp nhất trong 4 nhà kho. Chỉ có cuối năm 2015 là đột ngột tăng cao, khả năng là nhà kho này đang bù hàng vào đợt sales cuối năm cho các kho khác để tránh *outstock*.

-   Nhà kho J: ta thấy nhu cầu đặt hàng có mức độ biến động cao. Vì vậy, nhà kho này không chỉ cần phối hợp giữa việc *forecasting* và xây dựng nhiều *plan backup* để đảm bảo hàng không *outstock* cũng như giảm chi phí tồn kho (*inventory cost*).

-   Nhà kho C và S: nhu cầu đặt hàng có vẻ ổn định hơn chỉ trừ vài ngày nhu cầu tăng cao đột biển.

```{r}
#| warning: false
#| message: false
#| fig-cap: "Biểu đồ 1: Nhu cầu đặt hàng của 4 nhà kho A,J,C,S"
daily_df %>% 
  group_by(Warehouse) %>% 
  plot_time_series(Date, 
                   daily_demand,
                   .facet_ncol  = 2,
                   .smooth      = F,
                   .interactive = TRUE)
```

Sau khi hiểu rõ về dữ liệu đầu vào, chúng ta sẽ đi tới phần xây dựng mô hình. Bước đầu tiên vẫn là chia bộ dữ liệu ở tỉ lệ 7:3 thành *training set* và *testing set*. Ở đây, ta sẽ sử dụng các hàm sau để:
  
  Đầu tiên, chúng ta cũng chia dữ liệu thành 2 bộ bằng hàm `time_series_split()`.

Sau đó, tạo biểu đồ bằng:
  
  -   `tk_time_series_cv_plan()`: Chuyển đổi dữ liệu đã resample thành dạng bảng.

-   `plot_time_series_cv_plan()`: Hiển thị dữ liệu đã resample thời gian.

```{r}
#| warning: false
#| message: false
#| fig-cap: "Biểu đồ 2: Dự báo nhu cầu ở 4 nhà kho trong 12 tháng tới"
splits <- time_series_split(daily_df, 
                            assess = "12 month",
                            cumulative = TRUE)

splits %>%
  tk_time_series_cv_plan() %>%
  plot_time_series_cv_plan(Date, 
                           daily_demand, 
                           .interactive = T)
```

## Chia dữ liệu:

Tiếp theo, chúng ta sẽ xây dựng mô hình với package `{recipe}`. Điều đặc biệt là trong R package `{timetk}` có kết hợp với `{recipe}` giúp ta dễ sử dụng:
  
  Các bước bao gồm:
  
  -   B1: Tạo đối tượng dạng class `recipe()` với dữ liệu từ *training set*.

-   B2: Sử dụng hàm `step_timeseries_signature()` để chuyển đổi từ dữ liệu ngày hoặc giờ thành nhiều tính năng có thể hỗ trợ cho việc xây dựng mô hình học máy với dữ liệu chuỗi thời gian.

-   B3: Tách bộ dữ liệu thành *training set* và *testing set* cùng với các đặc tính đã tạo ở trên bằng hàm `prep()` và `bake()`.

```{r}
#| warining: false
#| message: false

library(rsample)
library(recipes)
recipe_spec <- recipe(daily_demand ~ ., 
                      data = training(splits)) %>%
  step_timeseries_signature(Date) 

train_tbl <- training(splits) %>% bake(prep(recipe_spec), .)

test_tbl  <- testing(splits) %>% bake(prep(recipe_spec), .)
```

Bạn có thể thấy khi áp dụng kết hợp công thức `prep()` và `bake()` thì nhiều cột mới đã được thêm vào từ tính năng của "ngày". Đây là những tính năng chúng ta có thể sử dụng trong các mô hình học máy của mình.

Sau đó, chúng ta sẽ thêm các tinh

## Xây dựng mô hình:

Sau khi đã chuyển đổi dữ liệu thành **input** phù hợp, chúng ta sẽ đến phần xây dựng mô hình và dự đoán.

Ở đây, chúng ta sử dụng package `modeltime.h2o`. Nó sẽ huấn luyện và kiểm chứng chéo (*cross-validates*) nhiều mô hình học máy và học sâu (XGBoost GBM, GLM, Rừng ngẫu nhiên, GBM…), sau đó huấn luyện hai mô hình **Stacked Ensembled**, một trong tất cả các mô hình và một trong những mô hình tốt nhất của mỗi loại. Cuối cùng, mô hình tốt nhất được lựa chọn.

Vì nó không có sẵn trên CRAN nên bạn có thể tải theo cú pháp dưới đây và thông tin thêm ở đây [@mattdancho2024].

::: callout-tip
## Tải package Modeltime H2O: {.unnumbered}

`devtools::install_github("business-science/modeltime.h2o")`
:::
  
  ```{r}
#| warining: false
#| message: false
#| include: false
library(modeltime.h2o)
```

Lưu ý, trước khi sử dụng `modeltime.h2o`, cần phải kết nối với dạng H2O thông qua hàm `h2o.init()`.

```{r}
#| warining: false
#| message: false
#| output: false
h2o.init(
  nthreads = -1,
  ip       = 'localhost',
  port     = 54321
)
```

Trong `modeltime` cung cấp cho chúng ta một số hàm tùy theo phương pháp mà chúng ta lựa chọn để xây dựng mô hình như liệt kê dưới đây Bạn có thể kham khảo ở đường link [Business Science](hhttps://business-science.github.io/modeltime/articles/getting-started-with-modeltime.html).

::: {.panel-tabset}

## Auto ML:

````yaml
```{r}
model_spec <- automl_reg(mode = 'regression') %>%
  set_engine(
    engine                     = 'h2o',
    max_runtime_secs           = 5, 
    max_runtime_secs_per_model = 3,
    max_models                 = 3,
    nfolds                     = 5,
    exclude_algos              = c("DeepLearning"),
    verbosity                  = NULL,
    seed                       = 786
  ) 
```
```

Hàm `automl_reg()` để xây dựng mô hình theo phương pháp **Auto Machine Learning** - có khả năng đơn giản hóa quy trình học máy bằng cách tự động hóa các tác vụ như chọn đặc trưng (*feature selection*), chọn mô hình (*model selection*), điều chỉnh tham số (*hyperparameter tuning*) và đánh giá mô hình (*evaluation*).

**Auto Machine Learning** giúp nâng cao khả năng tiếp cận cho người dùng có ít kinh nghiệm, tăng tốc độ phát triển mô hình và cải thiện hiệu suất thông qua các thuật toán hiệu quả và phương pháp tổ hợp. Các framework phổ biến bao gồm H2O.ai, TPOT, AutoKeras và Google Cloud AutoML.

## Auto ARIMA:

Cú pháp:
  
  ````yaml
```{r}
model_fit_arima_no_boost <- arima_reg() %>%
  set_engine(engine = "auto_arima") %>%
  fit(daily_demand ~ Date, data = train_tbl)
```
```

Hàm `arima_reg()` là một hàm trong gói `parsnip` của R, dùng để xác định mô hình hồi quy ARIMA (AutoRegressive Integrated Moving Average) cho các bài toán dự đoán chuỗi thời gian. Hàm này khá giống với hàm `auto.arima()` mà mình đã xài ở bài trước.


## ML Models

So với các mô hình auto trên thì các mô hình **Machine Learning** có sự phức tạp và đòi hỏi kiến thức về ML ở người dùng cao hơn. Thông thường, để xây dựng được thì cần trải qua quy trình gồm các bước như:
  
  - *Create Preprocessing Recipe*.

- *Create Model Specifications*.

- *Use Workflow to combine Model Spec and Preprocessing, and Fit Model*.

:::
  
  ```{r}
## AutoML:
model_spec <- automl_reg(mode = 'regression') %>%
  set_engine(
    engine                     = 'h2o',
    max_runtime_secs           = 5, 
    max_runtime_secs_per_model = 3,
    max_models                 = 3,
    nfolds                     = 5,
    exclude_algos              = c("DeepLearning"),
    verbosity                  = NULL,
    seed                       = 786
  )
## Auto ARIMA model:
model_fit_arima_no_boost <- arima_reg() %>%
  set_engine(engine = "auto_arima") %>%
  fit(daily_demand ~ Date, data = train_tbl)
```

Đối với mô hình Machine Learning, mình sẽ thử hai phương pháp là:
  
  - **Random Forest**: Là một phương pháp **ensemble learning** được sử dụng cho các nhiệm vụ phân loại và hồi quy, kết hợp nhiều cây quyết định để cải thiện độ chính xác dự đoán. Nó hoạt động bằng cách xây dựng một số lượng lớn cây quyết định trong quá trình huấn luyện và xuất ra giá trị trung bình hoặc chế độ dự đoán của các cây cá nhân, từ đó giảm thiểu hiện tượng overfitting và tăng cường độ bền của mô hình.

- **Prophet Boost**: được thiết kế để nâng cao độ chính xác của dự đoán chuỗi thời gian bằng cách tích hợp các ưu điểm của Prophet với các kỹ thuật boosting. Nó tận dụng khả năng của Prophet trong việc quản lý tính mùa vụ, ngày lễ và sự thay đổi xu hướng, làm cho nó phù hợp với các mẫu phi tuyến. Phương pháp boosting huấn luyện nhiều mô hình theo thứ tự, cho phép các mô hình sau sửa chữa các lỗi của các mô hình trước đó, từ đó cải thiện hiệu suất tổng thể. Ứng dụng của nó đạt hiệu quả trong nhiều ứng dụng, chẳng hạn như dự đoán doanh số bán lẻ và dự đoán nhu cầu, cung cấp một giải pháp mạnh mẽ cho việc dự đoán chuỗi thời gian chính xác.

```{r}
## Recipe processing:
recipe_spec <- recipe(daily_demand ~ Date, train_tbl) %>%
  step_timeseries_signature(Date) %>%
  step_rm(contains("am.pm"), contains("hour"), contains("minute"),
          contains("second"), contains("xts")) %>%
  step_fourier(Date, period = 365, K = 5) %>%
  step_dummy(all_nominal())

recipe_spec<-recipe_spec %>% 
  prep() %>% 
  juice()

## Fit the workflow:
model_spec_rf <- rand_forest(trees = 500, min_n = 50) %>%
  set_engine("randomForest")

workflow_fit_rf <- workflow() %>%
  add_model(model_spec_rf) %>%
  add_recipe(recipe_spec %>% step_rm(date)) %>%
  fit(training(splits))

model_spec_prophet_boost <- prophet_boost(seasonality_yearly = TRUE) %>%
  set_engine("prophet_xgboost") 

workflow_fit_prophet_boost <- workflow() %>%
  add_model(model_spec_prophet_boost) %>%
  add_recipe(recipe_spec) %>%
  fit(training(splits))

workflow_fit_prophet_boost
```

```{r}
#| warining: false
#| message: false
#| output: false
library(modeltime.h2o)
library(parsnip)
## Tạo ra các tiêu chí cho mô hình:
model_spec <- automl_reg(mode = 'regression') %>%
  set_engine(
    engine                     = 'h2o',
    max_runtime_secs           = 5, 
    max_runtime_secs_per_model = 3,
    max_models                 = 3,
    nfolds                     = 5,
    exclude_algos              = c("DeepLearning"),
    verbosity                  = NULL,
    seed                       = 786
  ) 

## Dùng các tiêu chí đó để xây dựng train mô hình:
model_fitted <- model_spec %>%
  fit(daily_demand ~ ., 
      data = train_tbl)
```

Ngoài ra có một điều lưu ý khi bạn làm việc với `modeltime` đó là output từ R sẽ xuất hiện các dòng như kiểu `|=========================================| 100%` và khi xuất output ra dạng HTML hay PDF thì nó vẫn xuất hiện. Điều này làm xấu đi bài báo cáo của mình nên chúng ta có thể sử dụng hàm `invisible()` để R hiểu và chỉ đưa ra kết quả cuối cùng, bỏ qua thông báo từ process.

````yaml
```{r}
invisible(capture.output({
  ## Your modeltime code here
}))
```
```

Để xuất ra các mô hình tốt nhất xếp từ trên xuống từ R, bạn có thể dùng hàm `automl_leaderbord`. Kết quả sẽ lọc ra các mô hình tốt nhất được lưu trữ trong bảng xếp hạng dựa trên các chỉ số đánh giá quen thuộc như: **RMSE**,**MSE**,**MAE**,...

Theo mặc định, mô hình có giá trị trung bình về sai số thấp nhất sẽ được họn và trả về ở dạng class **H20AutoML**. Để biết thêm thông tin, hãy bạn có thể dùng cú pháp `?h2o.automl` ở console.

```{r}
#| echo: false
#| warning: false
#| fig-cap: "Bảng 3: Bảng so sánh sai số giữa 2 phương pháp"
m<-automl_leaderboard(model_fitted)
library(gt)
library(gtExtras)
gt(m %>% 
     select(c(model_id,
              mean_residual_deviance))) %>%
  cols_label(
    model_id = md("**Mô hình**"),
    mean_residual_deviance = md("**Sai số trung bình**")) %>%
  tab_header(
    title = md("**Đánh giá mô hình**"),
    subtitle = md("Nguồn: package modeltime.h2o")) %>% 
  gt_theme_538()
```

Kết quả show ở trên có vẻ khá tệ khi sai số trung bình quá cao và ta cần sử dụng phương pháp khác để dự đoán.


## Dự đoán bằng mô hình vừa xây dựng:

Cuối cùng, ta sẽ dùng mô hình tốt nhất được nhắc ở trên để dự đoán dữ liệu bằng hàm `predict`.

Bảng dưới đây trình bày về giá trị dự đoán ở cả 4 nhà kho. Vì để minh họa nên mình chỉ thể hiện 6 hàng đầu tiên của bảng.

```{r}
#| message: false
#| warning: false
#| fig-cap: "Biểu đồ 4: Dự đoán nhu cầu bằng mô hình ở 4 nhà kho"
invisible(capture.output({
  n<-predict(model_fitted, test_tbl)
}))

n<-head(n) %>% 
  mutate(Date = head(test_tbl$Date),
         Warehouse = c("A","C","J","S","A","C"))
library(gt)
library(gtExtras)
gt(n[c("Date","Warehouse",".pred")]) %>% 
  cols_label(
    Date = md("**Ngày dự báo**"),
    Warehouse = md("**Nhà kho**"),
    .pred = md("**Giá trị dự báo**")) %>%
  cols_align(
    align = "center",
    columns = Warehouse
  ) %>% 
  tab_header(
    title = md("**Kết quả dự báo**"),
    subtitle = md("Nguồn: package modeltime.h2o")) %>% 
  gt_theme_538()
```

## Đánh giá mô hình:

Sau khi đã dự đoán, việc quan trọng cuối cùng là đánh giá độ tốt của mô hình vừa train. Và package `modeltime` có cung cấp thêm hàm:
  
  -   `modeltime_table()`: chuyển đối tượng class *h2o* về dạng dữ liệu bảng.

-   `modeltime_calibrate()`: hàm để đánh giá mô hình được xây dựng.

-   `modeltime_forecast()`: hàm để dự đoán giá trị dựa trên mô hình được gán.

```{r}
#| warning: false
#| message: false
#| fig-cap: "Biểu đồ 5: So sánh giữa giá trị dự đoán từ mô hình và nhu cầu thực tế"
## Chuyển đối tượng thành dạng bảng để dễ dàng lấy dữ liệu:
# Disable progress bar for a specific block of code
modeltime_tbl <- modeltime_table(
  model_fitted
) 

## Đánh giá dữ liệu bằng hàm modeltime_calibrate và hiển thị giá trị dự đoán:
invisible(capture.output({
  k <- modeltime_tbl %>%
    modeltime_calibrate(test_tbl) %>%
    modeltime_forecast(
      new_data    = test_tbl,
      actual_data = daily_df,
      keep_data   = TRUE
    )
}))

# Create the initial forecast plot
forecast_plot <- plot_modeltime_forecast(k %>% 
                                           group_by(Warehouse),
                                         .facet_ncol = 2, 
                                         .interactive = FALSE)

# Rename the legend labels and customize colors
forecast_plot_custom <- forecast_plot +
  scale_color_manual(
    values = c("ACTUAL" = "darkgray", 
               "1_H2O AUTOML - GBM" = "red"),  # Optional: Custom colors
    labels = c("ACTUAL" = "Actual Value", 
               "1_H2O AUTOML - GBM" = "Model Value")  # New legend labels
  )

# Print the customized plot
print(forecast_plot_custom)
```

Kết quả đưa ra có vẻ khá tệ khi tới 90% tỉ lệ lệch giữa giá trị quan sát được và giá trị dự đoán vượt quá 5%. Có vẻ Machine Learning không dự đoán tốt đối với trường hợp dữ liệu là chuỗi thời gian.

```{r}
#| warning: false
#| message: false
#| layout: [[40,60]]
#| fig-cap: 
#| - "Bảng 6: Đánh giá độ chính xác của mô hình ở 4 nhà kho"
#| - "Biểu đồ 7: Sự chênh lệch giữa giá trị dự đoán và thực tế"
predict<-k %>% 
  filter(.key == "prediction") %>% 
  select(c(.index,Warehouse,.value)) %>% 
  rename(Date = .index,
         Predicted = .value) %>% 
  mutate(Observed = test_tbl$daily_demand,
         Diff = round((Observed - Predicted)/Observed*100,2),
         Check = ifelse(Diff <= 5 & Diff >= -5, "Passed","Failed"))

library(gt)
library(gtExtras)
gt(predict %>% 
     group_by(Warehouse) %>% 
     count(Check) %>% 
     mutate(Per = round(n/nrow(predict),3))) %>% 
  cols_label(
    Check = md("**Warehouse**"),
    n = md("**Count**"),
    Per = md("**Percentage**")) %>%
  tab_header(
    title = md("**Evaluating the model's accuracy**"),
    subtitle = glue::glue("Forecasting from {min(test_tbl$Date)} to {max(test_tbl$Date)}")) %>%
  tab_source_note(
    source_note = str_glue("Smaller 5% means passed")) %>% 
  gt_theme_538() %>% 
  data_color(columns = c("Check"),
             method = "factor",
             palette = c("red","blue")) %>%
  tab_options(
    table.width = pct(80),       # Setting the table width to 80% of the page width
    table.align = "center",      # Centering the table
    column_labels.font.size = px(14), # Increase font size of column labels
    table.font.size = px(12),    # Setting font size for the table
    heading.align = "center"     # Centering the heading of the table
  )

### Remove Outliers using IQR method:
filtered_data <- predict %>%
  group_by(Warehouse) %>%
  # Remove outliers using the IQR method
  filter(
    between(Diff, 
            quantile(Diff, 0.25) - 1.5 * IQR(Diff),
            quantile(Diff, 0.75) + 1.5 * IQR(Diff))
  ) %>%
  # Adjust values in the Warehouse column
  mutate(Warehouse = case_when(
    Warehouse == "Whse_A" ~ "Warehouse A",
    Warehouse == "Whse_C" ~ "Warehouse C",
    Warehouse == "Whse_J" ~ "Warehouse J",
    Warehouse == "Whse_S" ~ "Warehouse S",
    TRUE ~ as.character(Warehouse)  # Preserve other values if any
  ))

ggplot(data = filtered_data %>% 
         group_by(Warehouse),
       aes(x = Date, 
           y = Diff)) + 
  geom_point() +
  geom_smooth(method = "lm")+
  geom_abline(intercept = 1, 
              slope = 0, color="red", 
              linetype="dashed", 
              size=1)+
  xlab('Time') +
  ylab('Difference (%)') +
  theme_bw()+
  facet_wrap(~ Warehouse, scales = "free_y") +
  labs(title = "Evaluating model builded by GBM method",
       subtitle = "Observed vs Predicted value",
       caption = "The red line is abline Y = 0 means accuracry prediction and the blue line is the linear lines between observed and predicted value.")+
  theme(
    plot.title = element_text(hjust = 0.5, size = 16),  # Centering and resizing the title
    plot.subtitle = element_text(hjust = 0.5, size = 12), # Centering and resizing the subtitle
    axis.text = element_text(size = 10),  # Resizing axis text
    axis.title = element_text(size = 12)  # Resizing axis labels
  )
```

Điều mình thích nhất ở package này là ta có thể dễ dàng dự đoán cho nhiều đối tượng khác nhau chỉ với gán thêm hàm `group_by()`.

## Học lại dữ liệu và dự đoán tiếp:

Thực chất dữ liệu từ *training set* và *testing set* cũng được chia ra từ bộ dữ liệu đã biết ban đầu, còn dữ liệu trong tương lai chúng ta chưa biết. Ví dụ như ở đây, bộ dữ liệu này chỉ được thu thập tới ngày 30/12/2016 nên nhu cầu đặt hàng của khách hàng ở năm 2017 trở về sau là chưa biết. Vì vậy, chúng ta sẽ *refit* mô hình lại.

Hoạt động *refit* nghĩa là sử dụng mô hình đã được train và chứa tất cả dữ liệu mình có và dùng nó để dự đoán giá trị cho một khoảng thời gian sắp tới.

```{r}
#| warining: false
#| message: false
#| output: false
## Gộp dữ liệu từ training set và testing set thành một:
data_prepared_tbl <- bind_rows(train_tbl, test_tbl)


## Tạo thêm các hàng cho dữ liệu sắp tới. Ví dụ ta cần trong 6 tháng thì hàm sẽ tạo thêm 365*4 = 1460 hàng:
future_tbl <- data_prepared_tbl %>%
  group_by(Warehouse) %>%
  future_frame(.length_out = "6 months") %>%
  ungroup()

## Tạo thêm các đặc tính khác của dữ liệu giống như trên đã làm:
future_prepared_tbl <- bake(prep(recipe_spec), future_tbl)
```

::: callout-warning
## Chỉnh thời gian dự đoán {.unnumbered}

Bạn có thể chỉnh khoảng thời gian cần dự đoán theo ý bạn trong hàm `future_frame` bằng đối số `.length_out`.

Ví dụ một năm thì `= "1 year"`, 45 phút thì `= "45 minutes"`.
:::
  
  Và cuối cùng là dự đoán nhu cầu đặt hàng cho từng nhà kho trong 6 tháng tiếp theo.

```{r}
#| warining: false
#| message: false
#| output: false
refit_tbl <- modeltime_tbl %>%
  modeltime_refit(data_prepared_tbl)
```

```{r}
#| warning: false
#| message: false
#| fig-cap: "Biểu đồ 8: Giá trị dự đoán nhu cầu cho 4 nhà kho trong 6 tháng tiếp theo"

invisible(capture.output({
  refit_tbl<-refit_tbl %>%
    modeltime_forecast(
      new_data    = future_prepared_tbl,
      actual_data = data_prepared_tbl,
      keep_data   = TRUE)
  
  refit_tbl %>% 
    group_by(Warehouse) %>% 
    plot_modeltime_forecast(
      .facet_ncol = 2, 
      .interactive = FALSE)
}))
```

# Kết luận:

Như các bạn đã thấy, package `modeltime` trong R là một công cụ mạnh mẽ để dự báo chuỗi thời gian giúp nâng cao hiệu suất và hiệu suất của quá trình lập mô hình. Điều mình thích nhất chính là không cần phải chuyển đổi dữ liệu chuỗi thời gian sang dạng `zoo` hay `xts` như thông thường mình làm để phân tích. Mặc dù kết quả dự đoán không tốt nhưng thật sự package này giúp ích rất nhiều cho việc phân tích dữ liệu chuỗi thời gian.

Nếu bạn có câu hỏi hay thắc mắc nào, đừng ngần ngại liên hệ với mình qua Gmail. Bên cạnh đó, nếu bạn muốn xem lại các bài viết trước đây của mình, hãy nhấn vào hai nút dưới đây để truy cập trang **Rpubs** hoặc mã nguồn trên **Github**. Rất vui được đồng hành cùng bạn, hẹn gặp lại! 😄😄😄

```{=html}
<!DOCTYPE html>
  <html lang="en">
  <head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Contact Me</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.3/css/all.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/simple-icons@v6.0.0/svgs/rstudio.svg">
  <style>
  body { font-family: Arial, sans-serif; background-color: #f9f9f9; }
      .container { max-width: 400px; margin: auto; padding: 20px; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1); }
    label { display: block; margin: 10px 0 5px; }
    input[type="email"] { width: 100%; padding: 10px; margin-bottom: 15px; border: 1px solid #ccc; border-radius: 4px; }
      .github-button, .rpubs-button { margin-top: 20px; text-align: center; }
      .github-button button, .rpubs-button button { background-color: #333; color: white; border: none; padding: 10px; cursor: pointer; border-radius: 4px; width: 100%; }
          .github-button button:hover, .rpubs-button button:hover { background-color: #555; }
              .rpubs-button button { background-color: #75AADB; }
                  .rpubs-button button:hover { background-color: #5A9BC2; }
                      .rpubs-icon { margin-right: 5px; width: 20px; vertical-align: middle; filter: brightness(0) invert(1); }
                    .error-message { color: red; font-size: 0.9em; margin-top: 5px; }
                    </style>
                      </head>
                      <body>
                      <div class="container">
                      <h2>Contact Me</h2>
                      <form id="emailForm">
                      <label for="email">Your Email:</label>
                      <input type="email" id="email" name="email" required aria-label="Email Address">
                      <div class="error-message" id="error-message" style="display: none;">Please enter a valid email address.</div>
                      <button type="submit">Send Email</button>
                      </form>
                      <div class="github-button">
                      <button>
                      <a href="https://github.com/Loccx78vn" target="_blank" style="color: white; text-decoration: none;">
                      <i class="fab fa-github"></i> View Code on GitHub
                    </a>
                      </button>
                      </div>
                      <div class="rpubs-button">
                      <button>
                      <a href="https://rpubs.com/loccx" target="_blank" style="color: white; text-decoration: none;">
                      <img src="https://cdn.jsdelivr.net/npm/simple-icons@v6.0.0/icons/rstudio.svg" alt="RStudio icon" class="rpubs-icon"> Visit my RPubs
                    </a>
                      </button>
                      </div>
                      </div>
                      
                      <script>
                      document.getElementById('emailForm').addEventListener('submit', function(event) {
                        event.preventDefault(); // Prevent default form submission
                        const emailInput = document.getElementById('email');
                        const email = emailInput.value;
                        const errorMessage = document.getElementById('error-message');
                        
                        // Simple email validation regex
                        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
                        
                        if (emailPattern.test(email)) {
                          errorMessage.style.display = 'none'; // Hide error message
                          const yourEmail = 'loccaoxuan103@gmail.com'; // Your email
                          const gmailLink = `https://mail.google.com/mail/?view=cm&fs=1&to=${yourEmail}&su=Help%20Request%20from%20${encodeURIComponent(email)}`;
                          window.open(gmailLink, '_blank'); // Open in new tab
                        } else {
                          errorMessage.style.display = 'block'; // Show error message
                        }
                      });
                    </script>
                      </body>
                      </html>
                      ```
                    