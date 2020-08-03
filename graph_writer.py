#! /usr/bin/env python2
## This is a script given to me by Choongwon Jeong, to which I made quality of life changes, like adding helptext, --outDir, and the option for only outputting 1way models. He verbally confirmed to me he is ok with me putting this script in the repository and adding documentation. 
import re, sys, os, gzip, errno
from operator import itemgetter
import numpy as np
arg = sys.argv

VERSION="0.1.0"
## Description of flags
##   --in:            A prefix for the input scaffold graph
##   --at:            specify edge to add a branch in; otherwise, generate all possible cases
##   --pop:           Name of a population to be added
##   --include_root:  additionally explore two edges directly coming out of the root
##   --3way:          write down all graphs for three-way admixtue scenario
##   --outDir:        The directory to put the output graphs in.
##   --1way:          Only output 1 way models.
##   --version:       Print graph_writer version and exit.

def mkdir_p(path):
    try:
        os.makedirs(path)
    except OSError as exc:  # Python >2.5
        if exc.errno == errno.EEXIST and os.path.isdir(path):
            pass
        else:
            raise

def column(mat, i):
    return [row[i] for row in mat]

def node_name_writer(num):
    return ["n00" + str(i) if i < 10 else "n0" + str(i) if i < 100 else "n" + str(i) for i in range(num)]

def edge_writer(nd1, nd2):
    return ["edge", "b_" + nd1 + "_" + nd2, nd1, nd2]

def node_count(graph):
    # print graph
    ## If a line is commented, it will not be counted towards the node count.
    tv1 = sum([v[1:] if v[0] == "root" else v[2:] if v[0] == "label" or v[0] == "edge" else ["n000"] if v[0] == "#" else v[1:4] for v in graph], [])
    # print ""
    # print tv1
    return max([int(tv[1:]) for tv in tv1]) + 1


## A function to add a population
def add_edge(graph, edpos, pn=""):
    nnum = node_count(graph)
    
    ## If a single edge is specified, model one as splitting from there
    if len(edpos) == 1:
        ndnews = [val for val in node_name_writer(nnum+2) if int(val[1:]) >= nnum]
        tg2s = [vec for vec in graph if not (vec[0] == "edge" and vec[1] == edpos[0])]
        tg2out = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[0])][0]
        tg2s.append(edge_writer(tg2out[2], ndnews[0]))
        tg2s.append(edge_writer(ndnews[0], tg2out[-1]))
        tg2s.append(edge_writer(ndnews[0], ndnews[1]))
        if pn != "":
            tg2s.append(["label", pn, ndnews[-1]])
        g2s = []
        for rn in rns:
            g2s.extend([vec for vec in tg2s if vec[0] == rn])
        return g2s
    
    ## If two nodes are specified, model one as a mixture of the two
    if (len(edpos) == 2 or len(edpos) == 4) and edpos[0][0] == "n":
        ndnews = [val for val in node_name_writer(nnum+2) if int(val[1:]) >= nnum]
        tg2s = [vec for vec in graph]
        tg2s.append(edge_writer(ndnews[-2], ndnews[-1]))
        if len(edpos) == 4:
            tg2s.append(["admix", ndnews[-2], edpos[0], edpos[1], edpos[-2], edpos[-1]])
        else:
            tg2s.append(["admix", ndnews[-2], edpos[0], edpos[1], "50", "50"])
        if pn != "":
            tg2s.append(["label", pn, ndnews[-1]])
        g2s = []
        for rn in rns:
            g2s.extend([vec for vec in tg2s if vec[0] == rn])
        return g2s
    
    ## If two edges are specified, model one as a mixture of the two
    if (len(edpos) == 2 or len(edpos) == 4) and edpos[0][0] == "b":
        ndnews = [val for val in node_name_writer(nnum+6) if int(val[1:]) >= nnum]
        tg2s = [vec for vec in graph if not (vec[0] == "edge" and vec[1] in edpos)]
        tg2o1 = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[0])][0]
        tg2o2 = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[1])][0]
        tg2s.extend([edge_writer(tg2o1[2], ndnews[0]), edge_writer(ndnews[0], tg2o1[-1]), edge_writer(ndnews[0], ndnews[1])])
        tg2s.extend([edge_writer(tg2o2[2], ndnews[2]), edge_writer(ndnews[2], tg2o2[-1]), edge_writer(ndnews[2], ndnews[3])])
        tg2s.append(edge_writer(ndnews[-2], ndnews[-1]))
        if len(edpos) == 4:
            tg2s.append(["admix", ndnews[-2], ndnews[1], ndnews[3], edpos[-2], edpos[-1]])
        else:
            tg2s.append(["admix", ndnews[-2], ndnews[1], ndnews[3], "50", "50"])
        if pn != "":
            tg2s.append(["label", pn, ndnews[-1]])
        g2s = []
        for rn in rns:
            g2s.extend([vec for vec in tg2s if vec[0] == rn])
        return g2s
    
    ## If three nodes are specified, model one as a mixture of the three in order
    if (len(edpos) == 3 or len(edpos) == 6) and edpos[0][0] == "n":
        ndnews = [val for val in node_name_writer(nnum+4) if int(val[1:]) >= nnum]
        tg2s = [vec for vec in graph]
        tg2s.extend([edge_writer(ndnews[0], ndnews[1]), edge_writer(ndnews[2], ndnews[3])])
        if len(edpos) == 6:
            tg2s.append(["admix", ndnews[0], edpos[0], edpos[1], edpos[-3], edpos[-2]])
            tg2s.append(["admix", ndnews[2], ndnews[1], edpos[2], str(100-int(edpos[-1])), edpos[-1]])
        else:
            tg2s.append(["admix", ndnews[0], edpos[0], edpos[1], "50", "50"])
            tg2s.append(["admix", ndnews[2], ndnews[1], edpos[2], "50", "50"])
        if pn != "":
            tg2s.append(["label", pn, ndnews[-1]])
        g2s = []
        for rn in rns:
            g2s.extend([vec for vec in tg2s if vec[0] == rn])
        return g2s
    
    ## If three edges are specified, model one as a mixture of the three in order
    if (len(edpos) == 3 or len(edpos) == 6) and edpos[0][0] == "b":
        ndnews = [val for val in node_name_writer(nnum+10) if int(val[1:]) >= nnum]
        tg2s = [vec for vec in graph if not (vec[0] == "edge" and vec[1] in edpos)]
        tg2o1 = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[0])][0]
        tg2o2 = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[1])][0]
        tg2o3 = [vec for vec in graph if (vec[0] == "edge" and vec[1] == edpos[2])][0]
        tg2s.extend([edge_writer(tg2o1[2], ndnews[0]), edge_writer(ndnews[0], tg2o1[-1]), edge_writer(ndnews[0], ndnews[1])])
        tg2s.extend([edge_writer(tg2o2[2], ndnews[2]), edge_writer(ndnews[2], tg2o2[-1]), edge_writer(ndnews[2], ndnews[3])])
        tg2s.extend([edge_writer(tg2o3[2], ndnews[6]), edge_writer(ndnews[6], tg2o3[-1]), edge_writer(ndnews[6], ndnews[7])])
        tg2s.extend([edge_writer(ndnews[4], ndnews[5]), edge_writer(ndnews[8], ndnews[9])])
        if len(edpos) == 6:
            tg2s.append(["admix", ndnews[4], ndnews[1], ndnews[3], edpos[-3], edpos[-2]])
            tg2s.append(["admix", ndnews[8], ndnews[5], ndnews[7], str(100-int(edpos[-1])), edpos[-1]])
        else:
            tg2s.append(["admix", ndnews[4], ndnews[1], ndnews[3], "50", "50"])
            tg2s.append(["admix", ndnews[8], ndnews[5], ndnews[7], "50", "50"])
        if pn != "":
            tg2s.append(["label", pn, ndnews[-1]])
        g2s = []
        for rn in rns:
            g2s.extend([vec for vec in tg2s if vec[0] == rn])
        return g2s

r1 = os.getcwd() + "/"; os.chdir(r1)
argvec = [arg[i].split("=") for i in range(1,len(arg))]
flags = [val for val in column(argvec, 0)]

if "--version" in flags:
    print VERSION
    quit()

## Print option help
if "--help" in flags:
    print """
    ## Description of flags
    ##   --help:          Print this helptext and exit.
    ##   --in:            A prefix for the input scaffold graph
    ##   --at:            specify edge to add a branch in; otherwise, generate all possible cases
    ##   --pop:           Name of a population to be added
    ##   --include_root:  additionally explore two edges directly coming out of the root
    ##   --3way:          write down all graphs for three-way admixtue scenario
    ##   --outDir:        The directory to put the output graphs in.
    ##   --1way:          Only output 1 way models.
    ##   --version:       Print graph_writer version and exit.
    """; quit()

## 1. Write down a two-population graph if no graph is provided
if "--in" not in flags:
    p1s = [argval[1].split(",") for argval in argvec if argval[0] == "--pop"][0]
    if len(p1s) != 2:
        print "Please provide either a scaffold graph or two starting populations!"; quit()
    nnodes = 3; nlabels = node_name_writer(nnodes)
    string = "root\t" + nlabels[0] + "\n"
    string += "label\t" + p1s[0] + "\t" + nlabels[1] + "\n"
    string += "label\t" + p1s[1] + "\t" + nlabels[2] + "\n"
    string += '\t'.join(edge_writer(nlabels[0], nlabels[1])) + "\n"
    string += '\t'.join(edge_writer(nlabels[0], nlabels[2]))
    print string; quit()


## Otherwise, import the scaffold graph and the population to be added
inFile = [argval[1] for argval in argvec if argval[0] == "--in"][0]  ## Input scaffold graph's prefix
fileName = inFile.split("/")[-1]
p1 = ""
if "--pop" in flags:
    p1 = [argval[1] for argval in argvec if argval[0] == "--pop"][0]  ## A population to be added to the graph

g1s = [line.strip().split() for line in open(inFile + ".graph", "r").readlines()]

if "--outDir" in flags:
    outDir=[argval[1] for argval in argvec if argval[0] == "--outDir"][0]
    mkdir_p(outDir)
else:
    outDir="."
outFile = ("{}/{}".format(outDir,fileName) if p1 == "" else "{}/{}".format(outDir,fileName) + "." + p1)

if "--at" in flags:
    position=[argval[1] for argval in argvec if argval[0] == "--at"][0]

###################################################################
## 2. Write down a new graph including an additional population  ##

rns = ["root", "label", "edge", "admix", "lock"]

## 2.1. When the position was specified
if "--at" in flags and "?" in position:
    fixed_edge=position.split(",")[0]
    ## I would exclude edges from the root from the usual search
    if "--include_root" in flags:
        edges = [v[1] for v in g1s if v[0] == "edge"]
    else:
        edges = [v[1] for v in g1s if v[0] == "edge" and v[2] != "n000"]
    edge_pairs = sum([[[v1, v2] for v2 in edges[(j+1):]] for j,v1 in enumerate(edges[:(-1)])], [])
    test_pairs = []
    for i in range(len(edge_pairs)):
      if fixed_edge in edge_pairs[i]:
       test_pairs.append(edge_pairs[i])
    ## In usual cases, write down all 1-way and 2-way graphs
    ## First, write down all ways without admixture
    ## Then, write down all two-way admixture cases
    for i,edge in enumerate(test_pairs):
        F1 = open(outFile + ".2way." + str(i+1) + ".graph", "w")
        F1.writelines('\n'.join(['\t'.join(g2) for g2 in add_edge(g1s, edge, p1)]) + "\n")
        F1.close()

if "--at" in flags and "?" not in position:
    #print(argval)
    edge_pos = [argval[1].split(",") for argval in argvec if argval[0] == "--at"][0]  ## Edge to be splitted from (comma separated)
    nnum = node_count(g1s)
    F1 = open(outFile + ".1.graph", "w")
    F1.writelines('\n'.join(['\t'.join(g2) for g2 in add_edge(g1s, edge_pos, p1)]) + "\n")
    F1.close(); quit()


## 2.2. When the position was NOT specified: write down all possible combinations
if "--at" not in flags and p1 != "":
    ## I would exclude edges from the root from the usual search
    if "--include_root" in flags:
        edges = [v[1] for v in g1s if v[0] == "edge"]
    else:
        edges = [v[1] for v in g1s if v[0] == "edge" and v[2] != "n000"]
    edge_pairs = sum([[[v1, v2] for v2 in edges[(j+1):]] for j,v1 in enumerate(edges[:(-1)])], [])
    
    ## In usual cases, write down all 1-way and 2-way graphs
    if "--3way" not in flags:
        ## First, write down all ways without admixture
        for i,edge in enumerate(edges):
            F1 = open(outFile + ".1way." + str(i+1) + ".graph", "w")
            F1.writelines('\n'.join(['\t'.join(g2) for g2 in add_edge(g1s, [edge], p1)]) + "\n")
            F1.close()
        if "--1way" in flags:
            quit()
        ## Then, write down all two-way admixture cases
        for i,edge in enumerate(edge_pairs):
            F1 = open(outFile + ".2way." + str(i+1) + ".graph", "w")
            F1.writelines('\n'.join(['\t'.join(g2) for g2 in add_edge(g1s, edge, p1)]) + "\n")
            F1.close()
    
    ## If "--3way" flag is specified, write down all three-way mixture graphs
    else:
        edge_triplets = []
        for ep in edge_pairs:
            edge_triplets.extend([[ep[0], ep[1], v] for v in [val for val in edges if val not in ep]])
        for i,edge in enumerate(edge_triplets):
            F1 = open(outFile + ".3way." + str(i+1) + ".graph", "w")
            F1.writelines('\n'.join(['\t'.join(g2) for g2 in add_edge(g1s, edge, p1)]) + "\n")
            F1.close()
    quit()



