SG.HO.est <- function(lambda, AlphaPattern, Rl, higher.order)
{
  Aq <- c(higher.order$QuadNodes)
  WAq <- c(higher.order$QuadWghts)
  Rl <- c(Rl)
  if(is.null(lambda))
    lambda = higher.order$lambda

  K <- ncol(AlphaPattern)
  NR <- list()
  NR <- expectedNR(AlphaPattern, Rl, Aq, WAq, lambda[,1], lambda[,2])
    n <- NR$n
    r1 <- NR$r # nquad x K
    r0 <- NR$r0 # nquad x K

  npar <- 0

      d <- a <- vector("numeric",K)
      for(k in seq_len(K)){

        d[k] <- rootFinder(f = Lfj_intercept, interval = higher.order$InterceptRange,
                           aj = lambda[k,1],theta = Aq,r1 = c(r1[,k]), r0 = c(r0[,k]), n = n,
                           prior = higher.order$Prior, mu = higher.order$InterceptPrior[1],
                           sigma = higher.order$InterceptPrior[2])
        npar <- npar + 1
      }
      if(higher.order$model=="1PL"){
        a <- rootFinder(f = Lfj_commonslope, interval = higher.order$SlopeRange,
                        d = lambda[,2],theta = Aq,r1 = r1, r0 = r0, n = n,
                        prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                        sigma = higher.order$SlopePrior[2])
        npar <- npar + 1
      }else if(higher.order$model=="2PL"){
        for(k in seq_len(K)) {
          a[k] <- rootFinder(f = Lfj_slope, interval = higher.order$SlopeRange,
                             dj = lambda[k,2],theta = Aq, r1 = c(r1[,k]), r0 = c(r0[,k]), n = n,
                             prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                             sigma = higher.order$SlopePrior[2])
          npar <- npar + 1
        }
      }else if(higher.order$model=="Rasch"){
        a <- 1
      }else{
        stop("Higher-order model is not correctly specified.",call. = FALSE)
      }
      lambda[,1] <- a
      lambda[,2] <- d


    logprior <- logP_AlphaPattern(AlphaPattern, Aq, WAq, lambda[,1], lambda[,2])


  return(list(logprior=logprior,lambda=lambda,higher.order=higher.order,npar=npar))
}

HO.est <- function(lambda, AlphaPattern, HOgr, Rl, higher.order)
{
  Aq <- higher.order$QuadNodes
  WAq <- higher.order$QuadWghts
  if(is.null(lambda)){
    lambda = higher.order$lambda
  }
  K <- log2(nrow(AlphaPattern))
  NR <- list()
  n <- r1 <- r0 <- 0
  for(g in HOgr){
    NR[[g]] <- expectedNR(AlphaPattern, Rl[,g], Aq[,g], WAq[,g], lambda[[g]][,1], lambda[[g]][,2])
    n <- n + NR[[g]]$n
    r1 <- r1 + NR[[g]]$r
    r0 <- r0 + NR[[g]]$r0
  }
  npar <- 0
  #by default, anchor = "all"/0 => same slope + intercept across groups for all attributes; G1 - N(0,1); G+ EH
  # anchor = "none"/NA => different slopes + intercepts across groups for all atts. G1 N(0,1), G+ N(0,1)
  # anchor = c(k,k') => same slopes + intercepts for att k, k'. G1 N(0,1), G+ EH
  anchor <- higher.order$anchor
  if(length(anchor)==1){
    if(tolower(anchor)=="all"){
      #by default, anchor = "all"/0 => same slope + intercept across groups for all attributes; G1 - N(0,1); G+ EH

      d <- a <- vector("numeric",K)
      for(k in seq_len(K)){
        d[k] <- rootFinder(f = Lfj_intercept, interval = higher.order$InterceptRange,
                           aj = lambda[[HOgr[1]]][k,1],theta = Aq[,1],r1 = c(r1[,k]), r0 = c(r0[,k]), n = n,
                           prior = higher.order$Prior, mu = higher.order$InterceptPrior[1],
                           sigma = higher.order$InterceptPrior[2])
        npar <- npar + 1
      }
      if(higher.order$model=="1PL"){
        a <- rootFinder(f = Lfj_commonslope, interval = higher.order$SlopeRange,
                        d = lambda[[HOgr[1]]][,2],theta = Aq[,1],r1 = r1, r0 = r0, n = n,
                        prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                        sigma = higher.order$SlopePrior[2])
        npar <- npar + 1
      }else if(higher.order$model=="2PL"){
        # print(higher.order$Prior)
        for(k in seq_len(K)) {
          a[k] <- rootFinder(f = Lfj_slope, interval = higher.order$SlopeRange,
                             dj = lambda[[HOgr[1]]][k,2],theta = Aq[,1],
                             r1 = c(r1[,k]), r0 = c(r0[,k]), n = n,
                             prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                             sigma = higher.order$SlopePrior[2])
          npar <- npar + 1
        }
      }else if(higher.order$model=="Rasch"){
        a <- 1
      }else{
        stop("Higher-order model is not correctly specified.",call. = FALSE)
      }
      for(g in HOgr){
        lambda[[g]][,1] <- a
        lambda[[g]][,2] <- d
      }
      if(max(HOgr)>1){
        Pg_alpha_c <- ColNormalize(Rl)
        for(gg in 2:max(HOgr)){
          WAq[,gg] <-
            higher.order$QuadWghts[,gg]  <-
            colSums(PostTheta(AlphaPattern, Aq[,gg], WAq[,gg], lambda[[gg]][,1],lambda[[gg]][,2])*Pg_alpha_c[,gg])
          npar <- npar + length(higher.order$QuadWghts[,gg]) - 1
        }
      }


    }else if(tolower(anchor)=="none"){
      for(g in HOgr){
        for(k in seq_len(K)){
          lambda[[g]][k,2] <- rootFinder(f = Lfj_intercept, interval = higher.order$InterceptRange,
                                         aj = lambda[[g]][k,1],theta = Aq[,g],
                                         r1 = NR[[g]]$r[,k], r0 = NR[[g]]$r0[,k], n = NR[[g]]$n,
                                         prior = higher.order$Prior, mu = higher.order$InterceptPrior[1],
                                         sigma = higher.order$InterceptPrior[2])
          npar <- npar + 1
        }
        if(higher.order$model=="1PL"){
          lambda[[g]][,1] <- rootFinder(f = Lfj_commonslope, interval = higher.order$SlopeRange,
                                        d = lambda[[g]][,2],theta = Aq[,g],
                                        r1 = NR[[g]]$r,r0 = NR[[g]]$r0, n = NR[[g]]$n,
                                        prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                                        sigma = higher.order$SlopePrior[2])
          npar <- npar + 1
        }else if(higher.order$model=="2PL"){

          for(k in seq_len(K)) {
            lambda[[g]][k,1] <- rootFinder(f = Lfj_slope, interval = higher.order$SlopeRange,
                                           dj = lambda[[g]][k,2],theta = Aq[,g],
                                           r1 = NR[[g]]$r[,k], r0 = NR[[g]]$r0[,k], n = NR[[g]]$n,
                                           prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                                           sigma = higher.order$SlopePrior[2])
            npar <- npar + 1

        }
          }else if(higher.order$model=="Rasch"){
          lambda[[g]][,1] <- 1
        }else{
          stop("Higher-order model is not correctly specified.",call. = FALSE)
        }
      }
    }
  }
  if(is.numeric(anchor)){ # some atts are anchors - cannot be 1PL


      for(k in seq_len(K)){
        if(k %in% anchor){
          rr1 <- r1[,k]
          rr0 <- r0[,k]
          nn <- n
          dk <- rootFinder(f = Lfj_intercept, interval = higher.order$InterceptRange,
                           aj = lambda[[g]][k,1],theta = Aq[,g],r1 = rr1, r0 = rr0, n = nn,
                           prior = higher.order$Prior, mu = higher.order$InterceptPrior[1],
                           sigma = higher.order$InterceptPrior[2])
          npar <- npar + 1
        if(higher.order$model=="2PL"){
            ak <- rootFinder(f = Lfj_slope, interval = higher.order$SlopeRange,
                             dj = lambda[[g]][k,2],theta = Aq[,g],
                             r1 = rr1, r0 = rr0, n = nn,
                             prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                             sigma = higher.order$SlopePrior[2])
            npar <- npar + 1
        }else if(higher.order$model=="Rasch"){
          ak <- 1
        }else{
          stop("Higher-order model is not correctly specified.",call. = FALSE)
        }
          for(g in HOgr)  {
            lambda[[g]][k,2] <- dk
            lambda[[g]][k,1] <- ak
          }

        }else{

          for(g in HOgr){
            rr1 <- NR[[g]]$r[,k]
            rr0 <- NR[[g]]$r0[,k]
            nn <- NR[[g]]$n
            lambda[[g]][k,2] <- rootFinder(f = Lfj_intercept, interval = higher.order$InterceptRange,
                                           aj = lambda[[g]][k,1],theta = Aq[,g],
                                           r1 = rr1, r0 = rr0, n = nn,
                                           prior = higher.order$Prior, mu = higher.order$InterceptPrior[1],
                                           sigma = higher.order$InterceptPrior[2])
          npar <- npar + 1
          }
          if(higher.order$model=="2PL"){
            for(g in HOgr){
              rr <- NR[[g]]$r[,k]
              nn <- NR[[g]]$n
              lambda[[g]][k,1] <- rootFinder(f = Lfj_slope, interval = higher.order$SlopeRange,
                                             dj = lambda[[g]][k,2],theta = Aq[,g],
                                             r1 = rr1, r0 = rr0, n = nn,
                                             prior = higher.order$Prior, mu = higher.order$SlopePrior[1],
                                             sigma = higher.order$SlopePrior[2])
              npar <- npar + 1
            }
           }else if(higher.order$model=="Rasch"){
            ak <- 1
          }else{
            stop("Higher-order model is not correctly specified.",call. = FALSE)
          }
        }
      }


    Pg_alpha_c <- ColNormalize(Rl)
    for(gg in 2:max(HOgr)){
      WAq[,gg] <-
        higher.order$QuadWghts[,gg]  <-
        colSums(PostTheta(AlphaPattern, Aq[,gg], WAq[,gg], lambda[[gg]][,1],lambda[[gg]][,2])*Pg_alpha_c[,gg])
      npar <- npar + length(higher.order$QuadWghts[,gg]) - 1
    }

  }

logprior <- matrix(0,nrow(AlphaPattern),length(HOgr))
for(g in HOgr){
  logprior[,g] <- logP_AlphaPattern(AlphaPattern, Aq[,g], WAq[,g], lambda[[g]][,1], lambda[[g]][,2])

}
  return(list(logprior=logprior,lambda=lambda,higher.order=higher.order,npar=npar))
}


rootFinder <- function(f,interval,...){
  f1 <- f(interval[1],...)
  f2 <- f(interval[2],...)
  if(f1*f2>0 | f1==f2){
    ret <- ifelse(abs(f1)>abs(f2),interval[2],interval[1])
  }else{
    ret <- uniroot(f = f, interval = interval,...)$root
  }
  ret
}

Lfj_intercept <- function(dj, aj, theta, r1, r0, n, prior = FALSE, mu, sigma){
  P <- c(Pr_2PL_vec(theta,aj,dj)) #nnodes x 1
  if(prior){
    ret <- sum(r1 - (r1 + r0) * P) + (dj - mu) / (sigma^2)
  }else{
    ret <- sum(r1 -(r1 + r0) * P)
  }
  ret
}
Lfj_slope <- function(aj, dj, theta, r1, r0, n, prior = FALSE, mu, sigma){
  P <- c(Pr_2PL_vec(theta, aj, dj)) #nnodes x 1
  if(prior){
    ret <- sum(theta*(r1 - (r1 + r0) * P)) - (log(aj) - mu + sigma^2) /(aj * sigma^2)

  }else{
    ret <- sum(theta*(r1 - (r1 + r0) * P))
  }

  ret

}
Lfj_commonslope <- function(a,d,theta,r1, r0, n, prior = FALSE, mu, sigma){
  avec <- rep(a,length(d))
  P <- Pr_2PL_vec(theta, avec, d) #nnodes x K

  if(prior){
    ret <- sum(theta*(r1 - (r1 + r0) * P)) - (log(a) - mu + sigma^2) /(a * sigma^2)
  }else{
    ret <- sum(theta*(r1 - (r1 + r0) * P))
  }
  ret
}

# HO.SE <- function(a,d,Xloglik,alphapattern,theta,weight,K,model="1PL",h = 1e-7){
#   # This will overestimate standard errors
#   inp <- incomplogL(a=a, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)
#
#   hess <- matrix(NA,K,2)
#   if(model=="2PL"){
#
#       for(rr in 1:K){
#         aa <- a
#         dd <- d
#         x <- rep(0,K)
#         x[rr] <- h
#         hess[rr,1] <- (incomplogL(a=aa+x, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)- 2*inp +
#                          incomplogL(a=aa-x, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight))/(h^2)
#         hess[rr,2] <- (incomplogL(a=a, b=dd+x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)- 2*inp +
#                          incomplogL(a=a, b=dd-x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight))/(h^2)
#       }
#
#   }else if(model=="1PL"){
#     hess[,1] <- (incomplogL(a=aa+h, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)- 2*inp +
#                      incomplogL(a=aa-h, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight))/(h^2)
#     for(rr in 1:K){
#       dd <- d
#       x <- rep(0,K)
#       x[rr] <- h
#       hess[rr,2] <- (incomplogL(a=a, b=dd+x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)- 2*inp +
#                        incomplogL(a=a, b=dd-x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight))/(h^2)
#     }
#   }else if(model=="Rasch"){
#     for(rr in 1:K){
#       dd <- d
#       x <- rep(0,K)
#       x[rr] <- h
#       hess[rr,2] <- (incomplogL(a=a, b=dd+x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)- 2*inp +
#                        incomplogL(a=a, b=dd-x,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight))/(h^2)
#     }
#   }
#
#   return(hess)
# }

# HO.SE <- function(v,Xloglik,alphapattern,theta,weight,K,model="1PL"){
#
#     if(model=="2PL"){
#     a <- v[1:K]
#     d <- v[(K+1):(2*K)]
#   }else if(model=="1PL"){
#     a <- rep(v[1],K)
#     d <- v[-1]
#   }else if(model=="Rasch"){
#     a <- rep(1,K)
#     d <- v
#   }
#
#   incomplogL(a=a, b=d,logL = Xloglik, AlphaPattern = alphapattern, theta = theta, f_theta = weight)
# }
