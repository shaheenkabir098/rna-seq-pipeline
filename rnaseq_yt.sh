#!/bin/sh

#  rnaseq_yt.sh
#  RNA-seq
#
#  Created by Shaheen kabir on 28/8/24.
#  
start_time=$(date +%s)
echo "Script started at: $(date)"

#-------------------------------------------------------------------------------------------
# On Terminal (default)
cd
cd /Users/shaheenkabir/RNAseq_May_2020_remote-master/fastq

#-------------------------------------------------------------------------------------------
# Generating Fastqc report
fastqc rnaseq_data/demo.fastq
# Check the generated .html file. Check for the base quality, adapter content, gc ratio and figure out if any trimming is needed.

#-------------------------------------------------------------------------------------------
# Trimming using trimmomatic.jar
java -jar trimmomatic.jar SE -threads 8 rnaseq_data/demo.fastq rnaseq_data/demo_trimmed.fastq TRAILING:10 -phred33
# here SE means Single End reads. -threads is the allocated processors to run (here it is 8). input file location then output file location. TRAILING: refers to how many reads will be cut if quality score falls below the certain treshhold. At last -phred33 means newer version of data coming from ILLUMINA genome sequencer. In case of old data, it will be -phred66.         \
# In summary,     java -jar trimmomatic.jar [SE/PE] [-threads ] [input file] [output file] [TRAILING] [phred encode]
echo "Trimmomatic Finished Running"
# Check Fastqc report of trimmed data
fastqc rnaseq_data/demo_trimmed.fastq
#Check the quality of bases in demo_trimmed_fastqc.html file

#-------------------------------------------------------------------------------------------
# Align with reference index using HISAT2.
# Index file can be downloaded from https://daehwankimlab.github.io/hisat2/download/ for different organisms. Or you can create an index by using HISAT tool (Not recommended).
# hisat2 tolls will be used on docker image.
docker start hisat2_container
docker exec -it hisat2_container bash -c"
 
hisat2 -x /fastq/grch38/genome \
    -U /fastq/rnaseq_data/demo_trimmed.fastq \
    -S /fastq/rnaseq_output/demo.sam \
    -p 8 \
    -t"                     # -x flag takes the index files downloaded from hisat page.                             here genome is the base call of the files                                           genome.1.bt/genome.2.bt
                            # -U flag takes the trimmed data which we want to align.(fastq)
                            # -S flag represents the output file that we want to generate.
                            # -p give acces to 7 processor of computer to execute.
                            # -t will print a time log in terminal.
                            
# Now, we can stop the docker.
docker stop hisat2_container # on new terminal window

#-------------------------------------------------------------------------------------------
# After alignment, we got a .sam file. We need to convert it to a .bam file
samtools view -b -@ 7 rnaseq_output/demo.sam > rnaseq_output/demo.bam
# Then, we need to sort it.
samtools sort -@ 7 rnaseq_output/demo.bam > rnaseq_output/demo_sorted.bam
# here -@ flag indicate the processors we want to allocate to execute and -b indicate that the output will be in .bam format.
# Then we can index it. [Optional]
samtools index rnaseq_output/demo_sorted.bam
# it will generate a file called demo_sorted.bam.bai

# we can check it has correct format
# samtools view -h rnaseq_output/demo_sorted.bam

#-------------------------------------------------------------------------------------------
# we can quantify the alignment by using featureCounts. For this purpose we will be needing a .gtf file. we can download it from https://ftp.ensembl.org/pub/release-106/gtf/homo_sapiens/Homo_sapiens.GRCh38.106.gtf.gz and move it to /rnaseq_data  folder.
featureCounts -S 2 -a rnaseq_data/Homo_sapiens.GRCh38.106.gtf -o rnaseq_output/demo_featurecounts.txt rnaseq_output/demo_sorted.bam

                    # -S means the integer value for strand. for reverse strand, it is 2.
                    # -a takes the .gtf annotation file.
                    # -o indicates the output file and location.
                    # at last without any flag, the HISAT2 produced and sorted .bam file will go.
# Then, it will generate two file named demo_featurecounts.txt and demo_featurecounts.txt.summary which we can check.
cat rnaseq_output/demo_featurecounts.txt.summary
#  cat rnaseq_output/demo_featurecounts.txt
# Cut onlt first and seventh column from the .txt file to view it easily.
#   cat rnaseq_output/demo_featurecounts.txt | cut -f1,7

#-------------------------------------------------------------------------------------------
end_time=$(date +%s)
echo "Script ended at: $(date)"
# Calculate the duration
duration=$((end_time - start_time))

# Convert duration to hours, minutes, and seconds
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))
seconds=$((duration % 60))

# Print the time taken
echo "Script runtime: ${hours}h ${minutes}m ${seconds}s"
