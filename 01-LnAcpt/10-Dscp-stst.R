ld(f.hold.price)
ld(user.wnwk.sp)
ld(f.surv.flw)
library(stargazer)

f.fst.flw <- user.wnwk.sp[!sapply(to.cube.symbol, is.null), .(follow.date = min(follow.date)), keyby = .(from.cube.symbol)]
f.dscrp.ststc <- f.fst.flw[f.hold.price, on = .(from.cube.symbol = cube.symbol)]
f.dscrp.ststc[, ':='(stck = str_extract(stock.symbol, "([0-9]+)"), date = as.Date(created.at))]
f.hold.time <- f.surv.flw[issale == 1, .(cube.symbol, stck, date, price, hold.time)]

# Binding two download tabs with close price per day
sp.rb.dl1 <- fread("TRD_Dalyr.csv", header = T, sep = ',', encoding = 'UTF-8')
sp.rb.dl1[, ":="(stck = (formatC(Stkcd, flag = '0', width = 6)), date = as.Date(Trddt))
    ][, ":="(Trddt = NULL, Stkcd = NULL)]
sp.rb.dl2 <- fread("TRD_Dalyr1.csv", header = T, sep = ',', encoding = 'UTF-8')
sp.rb.dl2[, ":="(stck = (formatC(Stkcd, flag = '0', width = 6)), date = as.Date(Trddt))
    ][, ":="(Trddt = NULL, Stkcd = NULL)]
sp.rb.dl <- rbindlist(list(sp.rb.dl1, sp.rb.dl2)) %>% as.data.table()
rm(sp.rb.dl1, sp.rb.dl2)

f.dscrp.ststc <- sp.rb.dl[f.dscrp.ststc, on = .(stck, date)]
f.dscrp.ststc <- f.hold.time[f.dscrp.ststc, on = .(stck, cube.symbol = from.cube.symbol, date, price)]
f.dscrp.ststc[issale == 1, isgain := ifelse(hold.price - Clsprc < 0, 1, 0)
    ][, pre.follow := ifelse(date < follow.date, 1, 0)
    ][, pro.follow := ifelse(date > follow.date, 1, 0)
    ][, pre.period := as.Date(follow.date) - min(date), by = .(cube.symbol)]

# Descriptive statistics
# All trade sample
#f.dscrp.ststc[, ':='(trade.num = .N, trade.time = difftime(max(date), min(date), units = "weeks"), follow.date = as.Date(follow.date)), by = .(cube.symbol)
    #][isgain == 1, trade.num.gain := .N, by = .(cube.symbol)
    #][issale == 1, trade.num.sale := .N, by = .(cube.symbol)]

#ststc.all.trade <- f.dscrp.ststc[trade.time > 0 , unique(.SD), by = .(cube.symbol), .SDcol = colnames(f.dscrp.ststc)[c(5, 22:25)]
    #][, trade.time := as.character(trade.time) %>% as.numeric()
    #][, trade.num.per.week := trade.num/trade.time]

#stargazer(ststc.all.trade, type = "html", out = "ststc.all.trade.doc")

# Before follow first portfolio
pre.follow.trade <- f.dscrp.ststc[pre.follow == 1]
pre.follow.trade[, ':='(trade.num = .N, trade.time = difftime(max(date), min(date), units = "weeks"), follow.date = as.Date(follow.date)), by = .(cube.symbol)
    ][issale == 1, trade.num.sale := .N, by = .(cube.symbol)
    ][isgain == 1, trade.num.gain := .N, by = .(cube.symbol)
    ]

ststc.pre.follow <- pre.follow.trade[, unique(.SD), by = .(cube.symbol), .SDcol = colnames(pre.follow.trade)[c(5, 22:25)]
    ][, trade.time := as.character(trade.time) %>% as.numeric()
    ][!is.na(trade.num.sale), trade.sale.hold.time := mean(hold.time), by = .(cube.symbol)
    ][!is.na(trade.num.gain), trade.gain.hold.time := mean(hold.time), by = .(cube.symbol)
    ]

## Every cube statistic
ststc.pre.follow <- na.omit(ststc.pre.follow[, .SD[, -c(2, 4)]]) %>% unique()


# After follow first portfolio
pro.follow.trade <- f.dscrp.ststc[pro.follow == 1 & date - as.Date(follow.date) <= pre.period]
pro.follow.trade[, ':='(trade.num = .N, trade.time = difftime(max(date), min(date), units = "weeks"), follow.date = as.Date(follow.date)), by = .(cube.symbol)
    ][issale == 1, trade.num.sale := .N, by = .(cube.symbol)
    ][isgain == 1, trade.num.gain := .N, by = .(cube.symbol)
    ]

ststc.pro.follow <- pro.follow.trade[, unique(.SD), by = .(cube.symbol), .SDcol = colnames(pro.follow.trade)[c(5, 22:25)]
    ][, trade.time := as.character(trade.time) %>% as.numeric()
    ][!is.na(trade.num.sale), trade.sale.hold.time := mean(hold.time), by = .(cube.symbol)
    ][!is.na(trade.num.gain), trade.gain.hold.time := mean(hold.time), by = .(cube.symbol)
    ]
## Every cube statistic
ststc.pro.follow <- na.omit(ststc.pro.follow[, .SD[, - c(2, 4)]]) %>% unique()

ststc.pre.follow[, group := "pre.follow"]
ststc.pro.follow[, group := "pro.follow"]
ststc <- rbindlist(list(ststc.pre.follow, ststc.pro.follow), use.names = T)

a <- compareGroups(group ~ trade.num + trade.num.sale + trade.num.gain + trade.sale.hold.time + trade.gain.hold.time, data = ststc) %>% createTable(show.n = T)
export2word(a, file = 'a.doc', which.table = "descr")
export2md(a, file = 'a.doc', which.table = "both")
stargazer(a, out = "a.doc")
print(a, which.table = "both")