def obtain_sampleIDs(manifest):
   with open(manifest) as f:
      lines = f.readlines()
   samplesIDs = []
   for line in lines:
      samplesIDs.append(line.split(",")[0])
   if "sample-id" in samplesIDs: samplesIDs.remove("sample-id")
   return(samplesIDs)

# Example
# obtain_sampleIDs("/home1/ksong4/WZ/longMicrobiome/Scripts/snakemake/Manifest/SingleEndManifest.csv")

