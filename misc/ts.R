library(forecast)
library(jsonlite)
library(magick)

baseurl <- "https://analythium.github.io/covid-19"
load(url(file.path(baseurl, "data", "covid-19.RData")))
load(url(file.path(baseurl, "data", "covid-19-canada-alberta.RData")))
s <- read.csv("./data/covid-19-canada-alberta.csv")

fit_ts <- function(y, i, j, method="ets", log=FALSE, k=1) {
  method <- match.arg(method, c("ets", "arima", "lm", "sq"))
  yy <- y[i:j]
  x <- (j+1):(j+k)
  if (log)
    yy <- log(yy)
  if (method %in% c("lm", "sq")) {
    xx <- i:j
    xx2 <- xx^2
    m <- if (method == "lm")
      lm(yy ~ xx) else lm(yy ~ xx + xx2)
    p <- predict(m, data.frame(xx=x, xx2=x^2), interval="prediction")
    fit <- p[,"fit"]
    lwr <- p[,"lwr"]
    upr <- p[,"upr"]
  } else {
    m <- if (method == "ets")
      ets(yy) else auto.arima(yy)
    p <- forecast(m, k)
    fit <- p$mean
    lwr <- p$lower[,"95%"]
    upr <- p$upper[,"95%"]
  }
  if (log) {
    fit <- exp(fit)
    lwr <- exp(lwr)
    upr <- exp(upr)
  }
  if (method == "lm") {
    r <- if (log)
      exp(coef(m)[2L]) else sum(coef(m)) / coef(m)[1L]
  } else {
    r <- fit[1L] / y[j]
  }
  out <- list(i=i, j=j, k=k, method=method, y=y, x=x, obs=y[x],
    rate=as.numeric(r),
    fit=as.numeric(fit), lwr=as.numeric(lwr), upr=as.numeric(upr))
  class(out) <- "fit_ts"
  out
}
plot.fit_ts <- function(x, ylim=NULL, xlim=NULL, ...) {
  if (is.null(ylim))
    ylim <- c(0, m*max(x$y))
  if (is.null(xlim))
    xlim <- c(1, m*length(x$y))
  plot(x$y, ylim=ylim, xlim=xlim,
    type="l", col="grey", lty=2, lwd=2,
    xlab="days", ylab="cases", ...)
  if (x$k < 2) {
    lines(c(x$x, x$x), c(x$lwr, x$upr), col="#ff000044")
    points(x$x, x$obs, col=1, pch=19)
    points(x$x, x$fit, col=2, pch=19)
  } else {
    polygon(c(x$x, rev(x$x)),
      c(x$lwr, rev(x$upr)),
      col="#ff000044", border="#ff000044")
    lines(x$x, x$obs, col=1, lwd=2)
    lines(x$x, x$fit, col=2, lwd=2)
  }
  invisible(x)
}

eval_ts1 <- function(y, ...) {
  x <- fit_ts(y, ..., k=1)
  c(obs=x$obs, fit=x$fit, lwr=x$lwr, upr=x$upr,
    bias=(x$obs - x$fit), sq=(x$obs - x$fit)^2,
    int=(x$upr-x$lwr),
    inside=as.integer(x$upr >= x$obs && x$lwr <= x$obs))
}

eval_ts <- function(y, ..., w=NULL) {
  res <- list()
  for (j in 2:(length(y)-1L)) {
    i <- if (is.null(w))
      1L else max(1L, j-w-1L)
    res[[length(res)+1L]] <- c(i=i, j=j, eval_ts1(y, ..., i=i, j=j))
  }
  data.frame(do.call(rbind, res))
}

eval_all <- function(y) {
  suppressWarnings({
    res <- list(
      ets=eval_ts(y, method="ets", log=FALSE, w=NULL)[-(1:2),],
      ar=eval_ts(y, method="arima", log=FALSE, w=NULL)[-(1:2),],
      lm3=eval_ts(y, method="lm", log=FALSE, w=3)[-(1:2),],
      lm4=eval_ts(y, method="lm", log=FALSE, w=4)[-(1:2),],
      lm5=eval_ts(y, method="lm", log=FALSE, w=5)[-(1:2),],
      lm6=eval_ts(y, method="lm", log=FALSE, w=6)[-(1:2),],
      lm7=eval_ts(y, method="lm", log=FALSE, w=7)[-(1:2),],
      sq4=eval_ts(y, method="sq", log=FALSE, w=4)[-(1:2),],
      sq5=eval_ts(y, method="sq", log=FALSE, w=5)[-(1:2),],
      sq6=eval_ts(y, method="sq", log=FALSE, w=6)[-(1:2),],
      sq7=eval_ts(y, method="sq", log=FALSE, w=7)[-(1:2),],
      sq8=eval_ts(y, method="sq", log=FALSE, w=8)[-(1:2),],
      sq9=eval_ts(y, method="sq", log=FALSE, w=9)[-(1:2),],
      sq10=eval_ts(y, method="sq", log=FALSE, w=10)[-(1:2),],
      logets=eval_ts(y, method="ets", log=TRUE, w=NULL)[-(1:2),],
      logar=eval_ts(y, method="arima", log=TRUE, w=NULL)[-(1:2),],
      loglm3=eval_ts(y, method="lm", log=TRUE, w=3)[-(1:2),],
      loglm4=eval_ts(y, method="lm", log=TRUE, w=4)[-(1:2),],
      loglm5=eval_ts(y, method="lm", log=TRUE, w=5)[-(1:2),],
      loglm6=eval_ts(y, method="lm", log=TRUE, w=6)[-(1:2),],
      loglm7=eval_ts(y, method="lm", log=TRUE, w=7)[-(1:2),],
      logsq4=eval_ts(y, method="sq", log=TRUE, w=4)[-(1:2),],
      logsq5=eval_ts(y, method="sq", log=TRUE, w=5)[-(1:2),],
      logsq6=eval_ts(y, method="sq", log=TRUE, w=6)[-(1:2),],
      logsq7=eval_ts(y, method="sq", log=TRUE, w=7)[-(1:2),],
      logsq8=eval_ts(y, method="sq", log=TRUE, w=8)[-(1:2),],
      logsq9=eval_ts(y, method="sq", log=TRUE, w=9)[-(1:2),],
      logsq10=eval_ts(y, method="sq", log=TRUE, w=10)[-(1:2),]
    )
  })
  list(results=res, summary=t(sapply(res, colMeans))[,-(1:6)])
}

y <- s$Total_confirmed

i <- "canada-combined"
i <- "hungary"
y <- clean[[i]]$observed$confirmed


jj <- 40:(length(y)-4)
for (j in jj) {
  png(paste0("fit", j, ".png"), height=600, width=500)
  op <- par(mfrow=c(3,2), mar=c(1,1,1,1))
  plot(fit_ts(y, 1, j, "ets", log=FALSE, k=4),ann=FALSE, axes=FALSE)
  mtext("ETS", line=-5, at=1, adj=0, cex=1.5)
  plot(fit_ts(y, 1, j, "ets", log=TRUE, k=4),ann=FALSE, axes=FALSE)
  mtext("ETS (log)", line=-5, at=1, adj=0, cex=1.5)
  plot(fit_ts(y, 1, j, "ar", log=FALSE, k=4),ann=FALSE, axes=FALSE)
  mtext("ARIMA", line=-5, at=1, adj=0, cex=1.5)
  plot(fit_ts(y, 1, j, "ar", log=TRUE, k=4),ann=FALSE, axes=FALSE)
  mtext("ARIMA (log)", line=-5, at=1, adj=0, cex=1.5)
  plot(fit_ts(y, j-3, j, "lm", log=FALSE, k=4),ann=FALSE, axes=FALSE)
  mtext("LM", line=-5, at=1, adj=0, cex=1.5)
  plot(fit_ts(y, j-3, j, "lm", log=TRUE, k=4),ann=FALSE, axes=FALSE)
  mtext("LM (log)", line=-5, at=1, adj=0, cex=1.5)
  par(op)
  dev.off()
}
f <- paste0("fit", jj, ".png")
img <- image_read(f)
imgs <- image_animate(image_morph(img, 2), 5)
image_write(imgs, "covid-ets-fit.gif")
unlink(f)



#y <- s$Total_confirmed - s$Total_deaths - s$Total_recovered
y <- s$Total_confirmed
i <- 1 # start date
j <- 14 # end date
k <- 14 # forecast

fit_ts(y, 1, 20, "ets", log=FALSE)
fit_ts(y, 1, 20, "ets", log=TRUE)
fit_ts(y, 15, 20, "lm", log=FALSE)
fit_ts(y, 15, 20, "lm", log=TRUE)
fit_ts(y, 1, 20, "sq", log=FALSE)
fit_ts(y, 1, 20, "sq", log=TRUE)
fit_ts(y, 1, 20, "arima", log=FALSE)
fit_ts(y, 1, 20, "arima", log=TRUE)

plot(fit_ts(y, 1, 20, "ar", log=FALSE, k=3), 2)

e <- eval_all(y)
e$summary

v <- e$results$ar
v <- e$results$logsq6

plot(v$obs, v$fit, type="n", xlab="observed", ylab="fitted")
polygon(c(v$obs, rev(v$obs)), c(v$lwr, rev(v$upr)), border="grey", col="grey")
abline(0,1,lty=2)
lines(v$obs, v$fit)



i <- "canada-combined"
i <- "hungary"
e <- eval_all(clean[[i]]$observed$confirmed)
e$summary

v <- e$results$sq4
plot(v$obs, v$fit, type="n", xlab="observed", ylab="fitted")
polygon(c(v$obs, rev(v$obs)), c(v$lwr, rev(v$upr)), border="grey", col="grey")
abline(0,1,lty=2)
lines(v$obs, v$fit)

zz <- list()
for (i in names(clean)) {
  cat(i, "\n")
  flush.console()
  z <- try(eval_all(clean[[i]]$observed$confirmed))
  if (!inherits(z, "try-error"))
    zz[[i]] <- z$summary
}

rn <- rownames(zz[[1]])
rn <- c("ets", "ar", "lm4", "loglm4", "sq6", "logsq6")
table(unlist(sapply(zz, function(z) rn[which.min(abs(z[rn,"bias"]))])))
table(unlist(sapply(zz, function(z) rn[which.min(z[rn,"sq"])])))
table(unlist(sapply(zz, function(z) rn[which.min(abs(0.95-z[rn,"inside"]))])))

## lm can be slightly biased
## sq is least biased
## ets and loglm coverage are best

## i=1, change j


## compare lin/log, ets/lm different window sizes (coverage + bias)
## automate selection
## run on multiple countries to see how it works
## plot 1-day forecasts based on multiple models to see how that looks


rate_ts <- function(y, w=4, ...) {
  res <- list()
  for (j in w:(length(y)-1L)) {
    i <- max(1L, j-w-1L)
    res[[length(res)+1L]] <- fit_ts(y, i, j, method="lm", log=TRUE, k=1)
  }
  t(sapply(res, function(z) c(x=z$x, r=z$rate)))
}


y <- s$Total_confirmed

i <- "canada-combined"
i <- "hungary"
i <- "korea-south"
y <- clean[[i]]$observed$confirmed

rr <- rate_ts(y, w=4)
plot(rr, type="l")
lines(lowess(rr), lty=2)

