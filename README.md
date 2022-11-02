# qpWrapper
A collection of wrapper scripts for running and collating results from qpWave, qpAdm and qpGraph.

## qpWrapper.sh

### Setup
Before running qpWrapper.sh, a user needs to set up a configuration file and save it in `~/.qpWrapper.config`. 
An example of such a configuration file is provided in Example_.qpWrapper.config and shown below:
```
INDIR=/PATH/TO/INPUT/DATA
OUTDIR=/PATH/TO/OUTPUT/DIRECTORY ## Subdirectories will be created within this directory to contain the results from the runs.
GENO=$INDIR/INPUT.geno
SNP=$INDIR/INPUT.snp
IND=$INDIR/INPUT.ind
# IND=$INDIR/ALTERNATIVE.INPUT.ind  ## You can comment out lines and they won't be read in. This allows you to easily swap .ind files for example.
```
This file should be formatted as a valid `bash` script. Lines of this file can be commented out as needed to keep notes or make quick swaps between input files/datasets
On runtime, qpWrapper.sh will `source ~/.qpWrapper.config` to get access to variables `OUTDIR`, `GENO`, `SNP` and `IND`. 

The `OUTDIR` variable specifies the base output directory for qpWrapper.sh runs. Two subdirectories will be created within this directory,
named `qpWave` and `qpAdm`, that contain the auxilliary files and outputs of qpWave and qpAdm runs respectively. 

### Usage
A script to quickly create all necessary auxilliary files and submit qpWave/qpAdm jobs to a queue using `qsub`. Basic usage instructions are as follows:
```
	 usage: qpWrapper.sh [options] (qpWave|qpAdm)

This programme will submit multiple qpWave/qpAdm runs, one for each Sample, with the rest of your Left and Right pops constant.

Options:
-h, --help		Print this text and exit.
-S, --Sample		Name of your sample. Should correspond to the populations name of your sample in the '.ind' file. Can be provided multiple times.
-R, --Ref, --Right	The Right populations for your runs. Can be provided multiple times.
-L, --Left, --Source	The Left populations for your runs. For qpAdm, each Sample will be the first Left pop, followed by these. Can be provided multiple times.
-r, --rotating 		Populations to 'rotate' from the Lefts to the Rights. When provided, qpWrapper will submit multiple runs, each with one of the rotating populations
				added to the Lefts while the rest are added to the end of the list of Rights. Can be provided multiple times.
-D, --SubDir		When provided, results will be placed in a subdirectory with the name provided within the result directory. Deeper paths can be provided by using '/'.
-A, 			When provided, the option 'allsnps: YES' will NOT be provided.
-i, 			When provided, the option 'inbreed: YES' will NOT be provided.
-c, --chrom 		When provided, qpWave/qpAdm will only use snps from the specified chromosome. Chromosome names in eigenstrat format are integers.
-t, --test 		Used to test the commands to be submitted. Instead of submitting them, qpWrapper will simply print them, while still creating the required files. 
				Useful for troubleshooting and integrating with broader pipelines.
-v, --version 		Print qpWrapper version and exit.
-d, --debug 		Run while printing debug information.
```

Options `-S`, `-L`, `-R` can be provided multiple times, and are used to add a population to the list of Samples, Lefts or Rights respectively. 
The `-r` option works can also be provided multiple times, but instead implements a "rotation" of the specified populations. Multiple runs will be created, sequentially
placing one of the rotated populations into the Lefts, and the rest to the Rights. The `-A` and `-i` options can be provided to deactivate the `allsnps` and
`inbreed` options of qpWave and qpAdm, both of which will be set to YES by default within qpWrapper.sh.
The `-c` option passes the provided argument to the `chrom` option of qpWave/qpAdm.
The `-D` option can be used to place the auxilliary files and results from a set of runs into a specific subdirectory within the `OUTDIR/{qpWave,qpAdm}/` specified in
`.qpWrapper.config`.

### Modes of operation
qpWrapper.sh has two modes of operation (qpWave/qpAdm), provided as a positional argument when calling the script. Each mode submits jobs for
qpWave or qpAdm exclusively, but also deals differently with the input population lists. 

#### qpWave
In qpWave operation mode, qpWrapper.sh will ignore all populations provided as Samples (`-S`). If any rotating populations have been specified, these
will be rotated one by one into the Lefts, with the remainder being added to the Rights. A qpWave run will then be launched for the Lefts and Rights.

Running the following command
```
qpWrapper.sh -S Sample1 -S Sample2 -L Left1 -L Left2 -R Right1 -R Right2 -r rotated1 -r rotated2 -r rotated3 qpWave
```
will submit 3 qpWave runs with the following combination of Left/Right populations:
| Lefts  | Rights |
| ---------------------- | ---------------------------------- |
| Left1, Left2, rotated1 | Right1, Right2, rotated2, rotated3 |
| Left1, Left2, rotated2 | Right1, Right2, rotated1, rotated3 |
| Left1, Left2, rotated3 | Right1, Right2, rotated1, rotated2 |

If no rotating populations are provided, then a single qpWave run will be created with the specified combination of Left/Right populations.

#### qpAdm
In qpAdm operation mode, each Sample population (`-S`) is sequentially added to the TOP of the Left populations and a qpAdm run is started.
Any rotating populations (`-r`) are sequentially added to the Lefts, while the rest are added to the Rights. When rotation of populations is requested,
multiple qpAdm runs will be submitted for each sample, as shown below.

Running the following command
```
qpWrapper.sh -S Sample1 -S Sample2 -L Left1 -L Left2 -R Right1 -R Right2 -r rotated1 -r rotated2 -r rotated3 qpAdm
```
will submit 3 qpAdm runs per sample, for a total of 6 runs, with the following combination of Left/Right populations:
| Lefts  | Rights |
| ---------------------- | ---------------------------------- |
| Sample1, Left1, Left2, rotated1 | Right1, Right2, rotated2, rotated3 |
| Sample1, Left1, Left2, rotated2 | Right1, Right2, rotated1, rotated3 |
| Sample1, Left1, Left2, rotated3 | Right1, Right2, rotated1, rotated2 |
| Sample2, Left1, Left2, rotated1 | Right1, Right2, rotated2, rotated3 |
| Sample2, Left1, Left2, rotated2 | Right1, Right2, rotated1, rotated3 |
| Sample2, Left1, Left2, rotated3 | Right1, Right2, rotated1, rotated2 |

## qpParser.sh
A helper script to quickly collate the results of all qpWave/qpAdm/qpGraph runs in the current directory.

Basic Usage instructions:
```
	 usage: qpParser.sh [options]

This programme will parse the output of all qpWave/qpAdm/qpGraph output files in the folder and print out a summary.

options:
-h, --help		Print this text and exit.
--header		In qpGraph parsing, print a header line.
-t, --type		Specify the parsing type you require. If not provided, qpParser will try to infer the parsing type from the current directory path. One of qpAdm|qpWave|qpGraph.
-d, --details		When parsing qpWave, the tail difference for each rank will be printed (only n-1 rank is printed by default). When parsing qpAdm, the full list of right populations is displayed, instead of the qpWave directory for the model.
-s, --suffix		Input file prefix to look for. By default this is '.out' for qpWave/qpAdm parsing, and '.log' for qpGraph parsing.
-c, --cutoff		Z-Score cutoff for qpGraph parsing. When supplied, any absolute Z-Score above the cutoff will not be printed.
-v, --version		Print qpParser version and exit.
```

### Modes of operation
These can be specified with `-t`, or inferred from the directory path if not specified. 

#### qpWave
In qpWave parsing, qpParser.sh will print a table of results from qpWave outputs (`*.out`) in the current directory.
This table includes the subdirectory specified during the qpWrapper submission of runs (assuming qpWrapper was used),
comma separated lists of the Right and Left populations of the qpWave run, as well as the tail-difference between the model with maximum
rank and that with rank one below it. 
If the `-d` option is provided, additional details are printed. In addition to the aforementioned columns, an additional column stating the
number of independent waves of a model is printed. Furthermode, for each parsed qpWave output, an additional set of rows is pronted that includes the
tail difference between all successive model comparisons to models with fewer waves of ancestry, down to 1 wave.

Example output with details (`-d`):
```
Subdir	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	3.24788919e-38	waves: 5
Subdir	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	7.37072253e-281	waves: 4
Subdir	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	0	waves: 3
Subdir	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	0	waves: 2
Subdir	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	1	waves: 1
```

#### qpAdm
In qpAdm parsing, qpParser.sh will print a table of results from qpAdm outputs (`*.out`) in the current directory.
This table includes the Sample population of the run (i.e. 1st Left), the subdirectory of the run,
a comma separated list of the Left populations of the run, the p value of the full model, the inferred mixture proportion
from all source populations, and the error associated with those proportions, followed by the model code and pvalue of each
of the "best models" provided by qpAdm.

When the `-d` option is provided, the Subdirectory field is replaced by a comma separated list of the used Right populations instead.

Example output with details (`-d`):
```
Sample1	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	0.0203484	0.023	0.124	-0.082	0.581	0.353	0.006	0.013	0.030	0.047	0.029	00100	0.00197053	10100	0.00159801	11100	8.38404e-22	11101	5.11393e-51
Sample2	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	0.00015224	0.032	0.109	-0.087	0.490	0.456	0.005	0.010	0.025	0.039	0.024	00100	5.00564e-05	10100	1.13536e-08	11100	8.58664e-22	11101	2.63954e-89
Sample3	Right1,Right2,Right3,Right4,Right5,Right6,Right7,Right8	Left1,Left2,Left3,Left4,Left5	0.00194501	0.046	0.104	-0.070	0.512	0.408	0.006	0.011	0.025	0.039	0.025	00100	0.00134017	10100	1.81826e-15	11100	4.26891e-16	11101	2.916e-68

```

#### qpGraph
In qpGraph parsing, qpParser.sh will print a table of results from qpGraph outputs (`*.log`) in the current directory.
This table includes the name of the output file, the Likelihood score of the model, the degrees of freedom of the model, the
p-value of the model, the Z score of the worst f4difference between the real and modelled data, and the number of outlier
statistics in the model.

A cutoff for the Z score of the f4 difference can be provided with `-c`. When provided qpParser will not print out any information
on models where the worst f4difference exceeds the specified cutoff.

Additionally, providing the `--header` option in this mode will add a simple header to the output table.

Example output with header (`--header`):
```
Logfile	Score	dof	p-value	worst f4diff	num outliers
base_graph.2way.1000.log	30.740	54	0.995471	-4.106	44
base_graph.2way.1001.log	30.917	54	0.995129	-3.904	35
base_graph.2way.1002.log	31.140	54	0.994670	3.877	36
base_graph.2way.1003.log	30.928	54	0.995107	-3.904	44
```

## graph_writer.py
A python script to create graphs, or add specified populations to existing ones. The output of this script can be used as the graph input for qpGraph (`-g`).

### Usage
```
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
```
The `--in` option can be used to specify an input graph prefix (file must end in `.graph`) to add the population specified with `--pop` to. If this option is not
used, two populations can be specified as a comma separated list to `--pop` to create a base graph for those two populations.
When `--in` is omitted, the output graph is written to stdout.

The `--at` option can be used to specify the edge or branch to add the specified population on. When omitted, all possible
topologies where the specified population is added as a simple edge or as a two-way admixture will be created. By default, edges
coming from the root of the tree are not tested. This behaviour can be reversed by specifying `--include_root`.

When the `--3way` option is specified, all possible topologies where `--pop` is the result of a 3 way mixture will also be created.
Conversely, by specifying the `--1way` option, it is possible to only create graphs where the specified population is NOT the
result of an admixture event.

Finally, it is possible to specify the desired output directory, within which all output graphs should be created by using the `--outDir` option.

Example command:
```
graph_writer.py --pop=test1,test2 --outDir=test >test/base.graph                    ## Creates a 2 population base graph
graph_writer.py --in=test/base --pop=test3 --1way --outDir=./test --include_root    ## Places test3 to the base graph, creating two graphs in the process.
```
## qpGraph_dot_cleanup.py
A python script that takes the output `.dot` file from a qpGraph run and makes it prettier by removing the label from nodes that
are not named and changing their shape from bubbles to dots.

Example command:
```
qpGraph_dot_cleanup.py --in=my_final_graph.dot
```
This command will create a file called `my_final_graph.cleaned.dot` that can be used for plotting the final qpGraph with `dot -Tps`.

Providing the option `--out` allows the user to specify the desired output file name.

It is possible to change the title of the graph with the `--label` option. In default qpGraph output, this title is the name of the parameter file used for the run, followed by the most divergent F4 statistic between real and fitted data.

## slurm_qpWrapper.sh
An older version of qpWrapper.sh that worked with SLURM instead of SGE. Not in development anymore, but kept here for backwards
compatibility and future reference. Should still work but has fewer features than qpWrapper.sh.