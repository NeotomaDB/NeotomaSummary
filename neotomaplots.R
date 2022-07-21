library(httr)
library(dplyr)
library(ggplot2)
library(ggthemes)
library(jsonlite)
library(purrr)
library(forcats)
library(lubridate)
library(scales)

datasettypes <- function(x) {
  call <- httr::GET("http://api.neotomadb.org/v2.0/data/summary/dstypemonth",
                    query = list(start = x, end = x + 1))
  result <- jsonlite::fromJSON(httr::content(call, as = "text"))$data$data
  result$month <- x
  result$counts <- as.numeric(result$counts)
  return(result)
}

c_trans <- function(a, b, breaks = b$breaks, format = b$format) {
  a <- as.trans(a)
  b <- as.trans(b)

  name <- paste(a$name, b$name, sep = "-")

  trans <- function(x) a$trans(b$trans(x))
  inv <- function(x) b$inverse(a$inverse(x))

  trans_new(name, trans, inv, breaks, format = format)
}

rev_date <- c_trans("reverse", "time")

monthly_change <- 0:18 %>% map(datasettypes) %>% bind_rows()

mc2 <- fct_collapse(monthly_change$datasettype,
                    biomarker = "biomarker",
                    charcoal = c("charcoal",
                                "macrocharcoal",
                                "microcharcoal",
                                "charcoal surface sample"),
                    diatom = c("diatom", "diatom surface sample"),
                    geochemistry = "geochemistry",
                    insect = "insect",
                    LOI = "loss-on-ignition",
                    macroinvertebrate = "macroinvertebrate",
                    ostracode = c("ostracode surface sample"),
                    sedimentology = c("physical sedimentology",
                                      "paleomagnetic",
                                      "X-ray fluorescence (XRF)"),
                    "phytolith" = "phytolith",
                    "plant macrofossil" = "plant macrofossil",
                    pollen = c("pollen", "pollen trap",
                              "pollen surface sample"),
                    "stable isotope" = "specimen stable isotope",
                    "testate amoebae" = c("testate amoebae",
                                          "testate amoebae surface sample"),
                    "vertebrate fauna" = "vertebrate fauna",
                    "water chemistry" = "water chemistry")

monthly_change$datasettype <- mc2

monthly_out <- monthly_change %>%
  group_by(datasettype, month) %>%
  summarise(count = sum(counts)) %>%
  mutate(month = (Sys.Date() %m-% months(month, abbreviate = FALSE)))

out <- ggplot(monthly_out, aes(x = month, y = count, fill = datasettype)) +
  geom_bar(stat = "identity") +
  theme_tufte() +
  scale_fill_viridis_d(name = "Dataset Type") +
  scale_x_date(date_labels = "%b %Y") +
  xlab("Month") +
  ylab("Number of Datasets Uploaded") +
  theme(axis.title = element_text(face = "bold", size = 18),
        axis.text = element_text(family = "sans-serif", size = 10))

ggsave("outputs/datasetsPerMonth.png", out, width = 8, height = 6, units = "in")
ggsave("outputs/datasetsPerMonth.svg", out, width = 8, height = 6, units = "in")

##################

datasetdbs <- function(x) {
  call <- httr::GET("http://api.neotomadb.org/v2.0/data/summary/dsdbmonth",
                    query = list(start = x, end = x + 1))
  result <- jsonlite::fromJSON(httr::content(call, as = "text"))$data$data
  result$month <- x
  result$counts <- as.numeric(result$counts)
  return(result)
}

monthly_change <- 0:16 %>%
  map(datasetdbs) %>%
  bind_rows() %>%
  mutate(month = (Sys.Date() %m-% months(month, abbreviate = FALSE)))

out <- ggplot(monthly_change,
              aes(x = month, y = counts, fill = databasename)) +
  geom_bar(stat = "identity") +
  theme_tufte() +
  scale_fill_viridis_d(name = "Constituent Database") +
  scale_x_date(date_labels = "%b %Y") +
  xlab("Month") +
  ylab("Number of Datasets Uploaded") +
  theme(axis.title = element_text(face = "bold", size = 18),
        axis.text = element_text(family = "sans-serif", size = 10))

ggsave("outputs/constDBPerMonth.png", out, width = 16, height = 4, units = "in")
ggsave("outputs/constDBPerMonth.svg", out, width = 16, height = 4, units = "in")

######################

rawmonthly <- function(x) {
  call <- httr::GET("http://api.neotomadb.org/v2.0/data/summary/rawbymonth",
                    query = list(start = x, end = 500))
  result <- jsonlite::fromJSON(httr::content(call, as = "text"))$data$data
  result$month <- x
  return(result)
}

monthly_change <- 0:100 %>%
  map(rawmonthly) %>%
  bind_rows() %>%
  mutate(month = (Sys.Date() %m-% months(month, abbreviate = FALSE)))

output <- tidyr::gather(monthly_change, obs, count, -month)

out <- ggplot(output, aes(x = month, y = as.numeric(count), group = obs)) +
  geom_path() +
  facet_wrap(~obs, scales = "free_y") +
  theme_tufte() +
  scale_fill_viridis_d() +
  scale_x_date(date_labels = "%Y") +
  xlab("Month") +
  ylab("Number of Datasets Uploaded") +
  theme(axis.title = element_text(face = "bold", size = 18),
        axis.text = element_text(family = "sans-serif", size = 10))

ggsave("outputs/ChangeOverTime.png", out, width = 8, height = 4, units = "in")
ggsave("outputs/ChangeOverTime.svg", out, width = 8, height = 4, units = "in")
