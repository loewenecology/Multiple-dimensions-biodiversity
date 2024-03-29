#...............................................................................................................................#
#...........Climate warming moderates the impacts of introduced sportfish on multiple dimensions of prey biodiversity...........#
#...............................................................................................................................#

#...............................................................................................................................#
#...........Author of the script: Charlie Loewen................................................................................#
#...............................................................................................................................#

#########################################################################
################# For generating metrics used to evaluate effect of sportfish introduction on prey biodiversity
#########################################################################

##################
# Load R packages
##################

library(adiv)
library(adespatial)
library(ape)
library(FD)
library(picante)

##################
# Load data in R environment
##################

zoop=read.table("Zoop_data-sp_relabund.csv",header=T,sep=",",row.names = 1) #site by species matrix with additional columns for feeding guilds
traits=read.table("Zoop_data-sp_traits.csv",header=T,sep=",",row.names = 1) #species by trait matrix
phylo=read.tree("Zoop_data-sp_tree",header=T,sep=",",row.names = 1) #phylogenetic tree

##################
# Prepare species data
##################

# Reduce to taxonomic data
zoop.abund<-zoop[36:130] #in this case, columns 1:35 held extra (non-species) data

# Create second taxonomic data frame with presence absence data
zoop.pres<-as.data.frame((zoop.abund != 0)*1)

# Reduce to feeding guild data 
feed.abund<-zoop[131:134] #in this case, columns 131:134 held feeding guild info (summarizing the species info)

# Create second feeding guild data frame with presence absence data
feed.pres<-as.data.frame((feed.abund != 0)*1)

# Reduce to feeding guild vector 
feed.trait<-traits[2] #in this case, feeding guild info was in column two

# Reduce to body size vector 
size.trait<-zoop[3] #in this case, body size info was in column three

##################
# Taxonomic metrics 
##################

# Taxonomic evenness (as inverse Simpson index divided by species richness)
Taxo.evenness <- eveparam(zoop.abund, method = "hill", q = 2)

# Taxonomic compositional uniqueness (as LCBD based on Sørensen dissimilarity)
Taxo.BS.Sorensen <- beta.div.comp(zoop.pres, coef="BS", quant = FALSE)
Taxo.BS.Sorensen.D.LCBD <- LCBD.comp(Taxo.BS.Sorensen$D, sqrt.D = TRUE) #sqrt.D = TRUE, because Taxo.BS.Sorensen.D is not Euclidean

# Ternary plot (Taxonomic compositional uniqueness)
out.comp.3 <- cbind((1-Taxo.BS.Sorensen$D), #change to similarity
                    Taxo.BS.Sorensen$repl,
                    Taxo.BS.Sorensen$rich)
colnames(out.comp.3) <- c("Similarity", "Replacement", "Nestedness")

triangle.plot(as.data.frame(out.comp.3[, c(3, 1, 2)]), show = FALSE, labeltriangle = FALSE, addmean = TRUE)
text(-0.45, 0.5, "Nestedness", cex = 1.5)
text(0.4, 0.5, "Replacement", cex = 1.5)
text(0, -0.6, "Sørensen  Similarity", cex = 1.5)

# Display values of the mean points in the triangular plots
colMeans(out.comp.3[, c(3, 1, 2)])

##################
# Feeding guild metrics 
##################

# Feeding guild richness
Feed.FD.metrics <- dbFD(feed.trait, feed.abund, w.abun = TRUE, stand.x = TRUE, calc.CWM = TRUE)
Feed.richness <- feed.FD.metrics$sing.sp

# Feeding guild evenness (as inverse Simpson index divided by guild richness)
Feed.evenness <- eveparam(feed.abund, method = "hill", q=2)

# Feeding guild compositional uniqueness as LCBD based on Sørensen dissimilarity
Feed.BS.Sorensen <- beta.div.comp(feed.pres, coef = "BS", quant = FALSE)
Feed.BS.Sorensen.D.LCBD <- LCBD.comp(Taxo.BS.Sorensen$D, sqrt.D = TRUE) #sqrt.D = TRUE, because Feed.BS.Sorensen.D is not Euclidean

# Feeding guild community weighted mean
Feed.CWM <- Feed.FD.metrics$CWM$x

##################
# Body size metrics 
##################

# Euclidean body size distances
size.trait.dist <- dist(size.trait)

# Body size richness (range)
Size.FD.pres.metrics <- dbFD(size.trait.dist, zoop.pres, w.abun = FALSE, )
Size.richness <- Size.FD.metrics$FRic

# Body size evenness (as functionally weighted Hill q2)
## FTD & FTD.comm from Scheiner, Kosman, Presley, & Willig. 2017. Decomposing functional diversity. Methods in Ecology and Evolution, 8:809-820.
## original R-script available at: https://github.com/ShanKothari/DecomposingFD

size.trait.dist.scaled <- size.trait.dist / max(size.trait.dist)

tdmat = size.trait.dist.scaled
spmat = zoop.abund

FTD <- function(tdmat, weights = zoop.pres, q = 2){
  
  # Contingency for one-species communities
  if(length(tdmat)==1 && tdmat==0){
    tdmat<-as.matrix(tdmat)
  }
  
  # is the input a (symmetric) matrix or dist? if not...
  if(!(class(tdmat) %in% c("matrix","dist"))){
    stop("distances must be class dist or class matrix")
  } else if(class(tdmat)=="matrix" && !isSymmetric(unname(tdmat))){
    warning("trait matrix not symmetric")
  } else if(class(tdmat)=="dist"){
    tdmat<-as.matrix(tdmat)
  }
  
  if(!isTRUE(all.equal(sum(diag(tdmat)),0))){
    warning("non-zero diagonal; species appear to have non-zero trait distance from themselves")
  }
  
  if(max(tdmat)>1 || min(tdmat)<0){
    tdmat<-(tdmat-min(tdmat))/(max(tdmat)-min(tdmat))
    warning("trait distances must be between 0 and 1; rescaling")
  }
  
  ## if no weights are provided, abundances are assumed equal
  if(is.null(weights)){
    nsp<-nrow(tdmat)
    weights<-rep(1/nsp,nsp)
  } else {
    nsp<-sum(weights>0)
  }
  
  if(!isTRUE(all.equal(sum(weights),1))){
    weights<-weights/sum(weights)
    warning("input proportional abundances do not sum to 1; summation to 1 forced")
  }
  
  tdmat.abund<-diag(weights) %*% tdmat %*% diag(weights)
  ## Here, because sum(weights)=1, the sum is here already adjusted by dividing by the 
  ## square of the number of species (if weights=NULL)
  ## or by multiplying by proportional abundances
  M<-sum(tdmat.abund)
  ## M equals Rao's Q in abundance-weighted calculations
  M.prime<-ifelse(nsp==1,0,M*nsp/(nsp-1))
  fij<-tdmat.abund/M
  
  ## calculating qHt
  ## fork -- if q=1, 1/(1-q) is undefined, so we use an analogue
  ## of the formula for Shannon-Weiner diversity
  ## if q!=1, we can calculate explicitly
  ## by definition, qHt=0 when all trait distances are zero
  if(isTRUE(all.equal(M,0))){
    qHt<-0
  } else if(q==1){
    fijlog<-fij*log(fij)
    fijlog[is.na(fijlog)]<-0
    qHt<-exp(-1*sum(fijlog))
  } else if(q==0){
    qHt<-sum(fij>0)
  } else {
    qHt<-sum(fij^q)^(1/(1-q))
  }
  
  ## getting qDT, qDTM, and qEt from qHt
  qDT<-(1+sqrt(1+4*qHt))/2
  qDTM<-1+qDT*M
  qEt<-qDT/nsp
  
  list(nsp=nsp,q=q,M=M,M.prime=M.prime,qHt=qHt,qEt=qEt,qDT=qDT,qDTM=qDTM)
}

FTD.comm <- function(tdmat, spmat, q = 2, abund = T, match.names = F){
  
  ## is the input a (symmetric) matrix or dist? if not...
  if(!(class(tdmat) %in% c("matrix","dist"))){
    stop("distances must be class dist or class matrix")
  } else if(class(tdmat)=="matrix" && !isSymmetric(unname(tdmat))){
    warning("trait matrix not symmetric")
  } else if(class(tdmat)=="dist"){
    tdmat<-as.matrix(tdmat)
  }
  
  if(!isTRUE(all.equal(sum(diag(tdmat)),0))){
    warning("non-zero diagonal; species appear to have non-zero trait distance from themselves")
  }
  
  if(max(tdmat)>1 || min(tdmat)<0){
    tdmat<-(tdmat-min(tdmat))/(max(tdmat)-min(tdmat))
    warning("trait distances must be between 0 and 1; rescaling")
  }
  
  if(abund==F){
    spmat[spmat>0]<- 1
    spmat<-spmat/rowSums(spmat)
  }
  
  n.comm<-nrow(spmat)
  if(match.names==T){
    sp.arr<-match(rownames(as.matrix(tdmat)),colnames(spmat))
    spmat<-spmat[,sp.arr]
  }
  
  ## apply FTD to each community in turn
  out<-apply(spmat,1,function(x) unlist(FTD(tdmat=tdmat,weights=x,q=q)))
  df.out<-data.frame(t(out))
  rownames(df.out)<-rownames(spmat)
  ## warning for zero-species communities
  if(sum(df.out$nsp==0)>0){
    warning("at least one community has no species")
  }
  
  nsp<-sum(colSums(spmat>0))
  ## this is Sw -- always an arithmetic mean, according to Evsey Kosman
  u.nsp<-mean(df.out$nsp)
  ## calculate mean richness, dispersion, evenness, FTD
  u.M<-sum(df.out$nsp*df.out$M)/sum(df.out$nsp)
  
  if(q==1){
    ## geometric mean -- limit of generalized mean as q->1
    u.qDT<-prod(df.out$qDT)^(1/n.comm)
  } else {
    ## generalized mean with m=1-q
    u.qDT<-(sum(df.out$qDT^(1-q))/n.comm)^(1/(1-q))
  }
  u.M.prime<-u.M*u.nsp/(u.nsp-1)
  
  ## calculate mean FTD and evenness
  u.qDTM<-1+u.qDT*u.M
  u.qEt<-u.qDT/u.nsp
  
  ## list more things
  list(com.FTD=df.out,nsp=nsp,u.nsp=u.nsp,u.M=u.M,u.M.prime=u.M.prime,u.qEt=u.qEt,u.qDT=u.qDT,u.qDTM=u.qDTM)
}

Size.evenness <- FTD.comm(tdmat, spmat, q = 2, abund = T, match.names = F)

# Body size compositional uniqueness as LCBD based on functional Sørensen dissimilarity
Size.PADDis.Sorensen <- PADDis(zoop.pres, size.trait.dist, method = 2, diag = FALSE, upper = FALSE)
Size.PADDis.Sorensen.LCBD = LCBD.comp(Size.PADDis.Sorensen, sqrt.D = TRUE) #sqrt.D = TRUE because Size.PADDis.Sorensen is not Euclidean

# Body size community weighted mean
Size.FD.abund.metrics <- dbFD(size.trait, zoop.abund, w.abun = TRUE)
Size.CWM <- Size.FD.abund.metrics$CWM$x

##################
# Phylogenetic metrics 
##################

# Euclidean phylogenetic distances
phylo.dist <- as.dist(cophenetic(phylo))

# Phylogenetic richness
Phylo.PD.richness <- pd(zoop.pres, phylo)

# Phylogenetic evenness (as phylogenetically weighted Hill q2; using FTD & FTD.comm as above)
phylo.dist.scaled <- phylo.dist / max(phylo.dist)
tdmat = phylo.dist.scaled
spmat = zoop.abund

Phylo.evenness <- FTD.comm(tdmat, spmat, q = 2, abund = T, match.names = F)

# Phylogenetic compositional uniqueness as LCBD based on phylogenetic Sørensen dissimilarity
Phylo.PADDis.Sorensen <- PADDis(zoop.pres, phylo.dist, method = 2, diag = FALSE, upper = FALSE)
Phylo.PADDis.Sorensen.LCBD = LCBD.comp(Phylo.PADDis.Sorensen, sqrt.D = TRUE) #sqrt.D = TRUE because Phylo.PADDis.Sorensen is not Euclidean

#...............................................................................................................................#
