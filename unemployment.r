# Load Required Libraries
library(tidyverse)
library(lubridate)
library(forecast)
library(tseries)
library(xgboost)
library(caret)
library(ggplot2)
library(tidyr) 
library(dplyr)  # Load dplyr package


# Load Unemployment Data
# Read the Unemployment Dataset (from local CSV)
df <- read.csv("unemployment.csv")

# Print column names to verify
colnames(df)

str(df)

colnames(df)[1] <- "DATE"  # Rename first column if necessary
colnames(df)[2] <- "Unemployment_Rate"  # Rename for clarity


# Remove empty or missing values
df <- df %>% filter(DATE != "" & !is.na(DATE) & !is.na(Unemployment_Rate))

# Verify changes
str(df)

# Convert DATE to Date Format
df$DATE <- as.Date(df$DATE, format="%Y-%m-%d")

# Rename Columns
colnames(df)[2] <- "Unemployment_Rate"

# Ensure the Unemployment Rate is Numeric
df$Unemployment_Rate <- as.numeric(df$Unemployment_Rate)
str(df)

# Remove any remaining NA values
df <- na.omit(df)

# Sort Data
df <- df %>% arrange(DATE)

# Check dataset structure
str(df)

# Plot Unemployment Rate Over Time
ggplot(df, aes(x = DATE, y = Unemployment_Rate)) +
  geom_line(color = "blue") +
  ggtitle("Unemployment Rate Over Time") +
  xlab("Year") +
  ylab("Unemployment Rate (%)")

# Convert to Time Series Object
start_year <- year(min(df$DATE))
unemployment_ts <- ts(df$Unemployment_Rate, start = c(start_year, 1), frequency = 12)

# Verify time series
print(unemployment_ts)

# Perform Augmented Dickey-Fuller Test for Stationarity
adf_test <- adf.test(unemployment_ts)
print(adf_test)


# Apply Differencing if Necessary
if (adf_test$p.value > 0.05) {
  unemployment_ts <- diff(unemployment_ts, differences = 1)
}

# Plot Differenced Series
autoplot(unemployment_ts) + ggtitle("Differenced Unemployment Rate")

# Decompose Time Series
unemployment_decomposed <- decompose(unemployment_ts)
autoplot(unemployment_decomposed)

# Split Data into Training and Testing (80-20 Split)
train_size <- round(0.8 * length(unemployment_ts))
train_ts <- window(unemployment_ts, end = c(start_year + train_size / 12, train_size %% 12))
test_ts <- window(unemployment_ts, start = c(start_year + train_size / 12, train_size %% 12))

# Fit ARIMA Model
arima_model <- auto.arima(train_ts)
summary(arima_model)

# Forecast Using ARIMA
arima_forecast <- forecast(arima_model, h = length(test_ts))

# Plot ARIMA Forecast vs Actual
autoplot(arima_forecast) +
  autolayer(test_ts, series = "Actual Data") +
  ggtitle("ARIMA Forecast vs Actual Unemployment Rate") +
  xlab("Year") +
  ylab("Unemployment Rate (%)") +
  theme_minimal()

# Evaluate ARIMA Model
arima_mae <- mean(abs(arima_forecast$mean - test_ts))
arima_rmse <- sqrt(mean((arima_forecast$mean - test_ts)^2))
cat("\nARIMA Model Performance:\n")
cat("MAE:", arima_mae, "\nRMSE:", arima_rmse, "\n")


# ------------------- XGBoost Machine Learning Model -------------------

# Create Lag Features for XGBoost
df$Year <- year(df$DATE)
df$Month <- month(df$DATE)
df$Lag_1 <- lag(df$Unemployment_Rate, 1)
df$Lag_12 <- lag(df$Unemployment_Rate, 12)
df <- na.omit(df)

# Train-Test Split (80-20)
train_size <- round(0.8 * nrow(df))
train_xgb <- df[1:train_size, c("Year", "Month", "Lag_1", "Lag_12")]
train_y <- df[1:train_size, "Unemployment_Rate"]
test_xgb <- df[(train_size + 1):nrow(df), c("Year", "Month", "Lag_1", "Lag_12")]
test_y <- df[(train_size + 1):nrow(df), "Unemployment_Rate"]

# Convert to XGBoost Matrix
train_matrix <- xgb.DMatrix(data = as.matrix(train_xgb), label = train_y)
test_matrix <- xgb.DMatrix(data = as.matrix(test_xgb), label = test_y)

# Train XGBoost Model
xgb_model <- xgboost(
  data = train_matrix,
  nrounds = 100,
  objective = "reg:squarederror",
  eta = 0.1
)

# Predict Using XGBoost
xgb_pred <- predict(xgb_model, test_matrix)

# Evaluate XGBoost Model
xgb_mae <- mean(abs(xgb_pred - test_y))
xgb_rmse <- sqrt(mean((xgb_pred - test_y)^2))
cat("\nXGBoost Model Performance:\n")
cat("MAE:", xgb_mae, "\nRMSE:", xgb_rmse, "\n")

# Plot XGBoost Forecast vs Actual
ggplot() +
  geom_line(aes(x = df$DATE[(train_size + 1):nrow(df)], y = test_y, color = "Actual")) +
  geom_line(aes(x = df$DATE[(train_size + 1):nrow(df)], y = xgb_pred, color = "XGBoost Forecast")) +
  ggtitle("XGBoost Forecast vs Actual Unemployment Rate") +
  xlab("Year") +
  ylab("Unemployment Rate (%)") +
  theme_minimal()

