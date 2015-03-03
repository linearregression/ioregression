#' Add a ridge penalty to an iolm object
#'
#' This function takes a pre-computed iolm object,
#' and applies a (sequence) of ridge penalties. An
#' intercept, if present in the original model, will
#' not be penalized.
#'
#' @param object     an iolm object with the desired formula
#' @param lambda     A scalar or vector of ridge constants.
#' @param normalize  If TRUE, each variable is standardized to have unit L2 norm,
#'                   otherwise it is left alone. Default is TRUE.
#' @export
iolm.ridge = function(object, lambda=seq(0,1,by=0.1), normalize=TRUE) {
  if (!inherits(object, "iolm"))
    stop("input to object must be an iolm object! See ?ioregression::iolm for more info.")

  n = object$n
  p = ncol(object$xtx)
  mean_y = object$sum_y / n
  mean_x = object$mean_x
  noms = names(out$coefficients)
  intercept = as.logical(attr(object$terms, "intercept"))


  XtY = object$xty
  XtX = object$xtx
  YtY = object$yty
  if (intercept) {
    mu = mean_y
    XtX = XtX[-1,-1]
    XtY = XtY[-1]
    mean_x = mean_x[-1]
    noms = noms[-1]
    p = p - 1
    XtY = XtY - n * mean_x * mean_y
    XtX = XtX - n * outer(mean_x,mean_x)
  } else mu = 0
  if (normalize) {
    normx = sqrt(Matrix::diag(XtX))
    names(normx) <- NULL
    XtX = XtX / outer(normx,normx)
    XtY = XtY / normx
  } else normx = rep(1,p)

  beta = sapply(lambda, function(l)
    as.numeric(Matrix::solve(XtX + Matrix::Diagonal(p,l),XtY)))
  beta = scale(t(beta), FALSE, normx)
  rownames(beta) = lambda
  MtM = XtX - outer(mean_x,mean_x)*n
  RSS = drop(YtY + Matrix::diag(beta %*% MtM %*% t(beta)) - 2 * beta %*% XtY
             - mu^2*n + 2 * n * mu * beta %*% mean_x)

  if (intercept) {
    beta = cbind(mu - beta %*% mean_x, beta)
    colnames(beta) = c("(Intercept)", noms)
  }

  sigma = summary.iolm(object)$sigma
  ev = eigen(XtX,only.values=TRUE)$values

  df = apply(ev / matrix(rep(ev,length(lambda)) + rep(lambda,
        each=length(ev)),ncol=length(lambda)),2,sum) + intercept
  names(df) = lambda

  out = list(coefficients=beta, lambda=lambda, intercept=intercept, df=df, RSS=RSS,
              AIC=n*log(RSS)+2*df, BIC=n*log(RSS)+log(n)*df,
              iolm=out, sigma = sigma, call=match.call())
  class(out) = c("iolm.ridge")
  return(out)
}

#' Print an ioridge object
#'
#' @method print iolm.ridge
#' @param x   an iolars object to print the summary of
#' @param ... other inputs; currently unused
#' @export
print.iolm.ridge = function (x, ...) {
  cat("\nCall:\n")
  dput(x$call)
  mat = cbind(lambda=x$lambda, df=x$df, RSS=x$RSS, AIC=x$AIC,
              BIC=x$BIC)
  rownames(mat) = rep("",nrow(mat))
  print(mat)
}

#' Summarize a ridge regression for a particular value of lambda
#'
#' @method summary iolm.ridge
#' @param object   an iolars object to print the summary of
#' @param lambda   a single lambda value
#' @param ...      other inputs; currently unused
#' @export
summary.iolm.ridge = function (object, lambda=object$lambda[which.min(object$AIC)], ...) {
  index = match(lambda[[1]], object$lambda)
  beta = object$coefficients[index,]
  p = length(beta)
  if (is.na(index))
    stop(sprintf("Cannot find lambda=%f",lambda[[1]]))

  lambda = rep(lambda, p)
  if (object$intercept) lambda[1] = 0
  W = object$iolm$xtx + Matrix::Diagonal(p,lambda)

  se = sqrt(Matrix::diag( Matrix::solve(W,object$iolm$xtx) %*% Matrix::solve(W) * object$sigma^2) / object$iolm$n)
  bias = -1 * lambda * Matrix::solve(W, beta)

  ans = cbind(beta, as.numeric(se), as.numeric(bias))
  rownames(ans) = colnames(object$coefficients)
  colnames(ans) = c("Estimate", "Bias", "Std. Error")
  ans
}
