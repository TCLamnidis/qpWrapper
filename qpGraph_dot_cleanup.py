#! /usr/bin/env python
## This script was given to me by Choongwon Jeong. He has verbally confirmed to me that he is ok with me putting this script in the repository.
import re, sys, os, gzip
import numpy as np
arg = sys.argv

def column(mat, i):
    return [row[i] for row in mat]

argvec = [arg[i].split("=") for i in range(1,len(arg))]

inFile = [argval[1] for argval in argvec if argval[0] == "--in"][0]

outFile = inFile + ".cleaned"
if "--out" in column(argvec,0):
    outFile = [argval[1] for argval in argvec if argval[0] == "--out"][0]


## label info
label = "NA"
if "--label" in column(argvec,0):
    label = [argval[1] for argval in argvec if argval[0] == "--label"][0]


r1 = os.getcwd() + "/"; os.chdir(r1)

g1s = [line.strip() for line in open(inFile + ".dot", "r").readlines()]

## Extract all nodes without label
nodes_all = sorted(list(set(sum([[v.split()[0], v.split()[2]] for v in g1s if "->" in v], []))))
nodes_lab = sorted(list(set([v.split()[0] for v in g1s if "[" in v and "label" in v and "->" not in v])))
gs_add = [val + '  [ label = "", shape=point ] ;' for val in nodes_all if val not in nodes_lab]

## Update label if a new one provided
label_old = [v for v in [g1 for g1 in g1s if len(g1) > 7] if v[0:7] == "label ="][0]
lnum = [i for i,v in enumerate(g1s) if v == label_old][0]
lv = (label_old if label == "NA" else 'label = "' + label)

## Write down a new graph
count = 0
F1 = open(outFile + ".dot", "w")
for i,g1 in enumerate(g1s):
    if i == lnum:
        F1.writelines(lv + "\n"); continue
    if "->" in g1 and count == 0:
        F1.writelines('\n'.join(gs_add) + "\n"); count += 1
    F1.writelines(g1 + "\n")

F1.close()


