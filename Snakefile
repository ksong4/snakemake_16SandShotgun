import configparser
import yaml

from pythonScripts import obtain_sampleIDs

## Path Definition
PROJECTNAME = "singleEndTest"
PROJECT_DIR = config["all"]["project_dir"]
QIIME2_OUTPUT_DIR = PROJECT_DIR + "/QIIME2_" + PROJECTNAME + "_output"
DEBLUR_OUTPUT_DIR = QIIME2_OUTPUT_DIR + "/deblur"
INTERMEDIATE_DIR = QIIME2_OUTPUT_DIR + "/intermediate"
DENOVO_EXPORT_DIR = INTERMEDIATE_DIR + "denovo_temp"

## Obtain parameters 
MANIFEST_FILEPATH = PROJECT_DIR + "/" + config["all"]["manifest"]
SAMPLE_IDS = obtain_sampleIDs.obtain_sampleIDs(MANIFEST_FILEPATH)
DEBLUR_TRIM_LENGTH = config["deblur"]["trim_length"]
PERCENT_IDENT = config["vsearch"]["percent_ident"]
CLASSIFIER = config["classifier"]["database"]

## RULES ##
## QIIME2 ## 
rule all:
	input:
	    # Demux Output 
	    QIIME2_OUTPUT_DIR + "/singleEndDemux.qza",
	    # Deblur Output
        rep_seq = DEBLUR_OUTPUT_DIR + "/deblur_rep_seqs.qza",
        table = DEBLUR_OUTPUT_DIR + "/deblur_table.qza",
        stats = DEBLUR_OUTPUT_DIR + "/deblur_stats.qza"
        # de Novo Output
        deNovo_req_seqs = INTERMEDIATE_DIR + "/deNovo_rep_seqs.qza",
        deNovo_table = INTERMEDIATE_DIR + "/deNovo_table.qza"
        # Classfied Reads
        classified_reads =INTERMEDIATE_DIR + "/deNovo_table.qza"



rule get_demux_qza:
    input: 
        PROJECT_DIR + "/Manifest/SingleEndManifest.csv"
    output:
        QIIME2_OUTPUT_DIR + "/singleEndDemux.qza"
    shell:
        """
        qiime tools import \
        --type 'SampleData[SequencesWithQuality]' \
        --input-path {input} \
        --output-path {output} \
        --input-format SingleEndFastqManifestPhred33 
        """

rule get_denoise:
    input:
        QIIME2_OUTPUT_DIR + "/singleEndDemux.qza"
    output:
        rep_seq = DEBLUR_OUTPUT_DIR + "/deblur_rep_seqs.qza",
        table = DEBLUR_OUTPUT_DIR + "/deblur_table.qza",
        stats = DEBLUR_OUTPUT_DIR + "/deblur_stats.qza"
    shell:
        """
		qiime deblur denoise-16S \
		  --i-demultiplexed-seqs {input} \
		  --p-trim-length -1 \
		  --p-sample-stats \
		  --o-representative-sequences {output.rep_seq} \
		  --o-table {output.table} \
		  --o-stats {output.stats} \
		  --verbose
        """ 

rule get_vsearch:
    input:
        rep_seq = DEBLUR_OUTPUT_DIR + "/deblur_rep_seqs.qza",
        table = DEBLUR_OUTPUT_DIR + "/deblur_table.qza",
    output:
        deNovo_req_seqs = INTERMEDIATE_DIR + "/deNovo_rep_seqs.qza",
        deNovo_table = INTERMEDIATE_DIR + "/deNovo_table.qza"
    shell:
        """
		qiime vsearch cluster-features-de-novo \
		  --i-table {input.rep_seq} \
		  --i-sequences {input.table} \
		  --p-perc-identity {PERCENT_IDENT} \
		  --o-clustered-table {output.deNovo_table} \
		  --o-clustered-sequences {output.deNovo_req_seqs}
        """ 

rule get_classified_reps:
    input:
        classifier = CLASSIFIER,
        reads = INTERMEDIATE_DIR + "/deNovo_rep_seqs.qza"
    output:
        classified_reads =INTERMEDIATE_DIR + "/deNovo_table.qza"
    shell:
        """
		qiime feature-classifier classify-sklearn \
			--i-classifier {classifier} \
			--i-reads {reads} \
			--o-classification {classified_reads}
        """ 

rule qiime2_export:
    input:
        classified_reads =INTERMEDIATE_DIR + "/deNovo_table.qza"
    output:
        rep_seq = DENOVO_EXPORT_DIR + "/"
    shell:
        """
		qiime tools export \
			--input-path {classified_reads} \
			--output-path {DENOVO_EXPORT_DIR}
        """ 

## Final parameters
workdir: PROJECT_DIR

onsuccess:
        print("Workflow finished, no error")
        shell("mail -s 'Workflow finished successfully' " + config["all"]["admin_email"] + " < {log}")

onerror:
        print("An error occurred")
        shell("mail -s 'An error occurred' " + config["all"]["admin_email"] + " < {log}")