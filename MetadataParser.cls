public  class MetadataParser {
    private MetadataParserSelector selector;
    public MetadataParser() {

        this.selector = new MetadataParserSelector();
    }

    public void ParseMetadaData(string externalDataSourceName,boolean deletePreviousData){

        if(deletePreviousData) {
            selector.DeletePrevRecords();
        }

        List<string> metadataChunckedFiles = selector.GetMetadataContent(externalDataSourceName);
        Odata_Service_Setting__mdt odataSettings = selector.GetOdataSettings(externalDataSourceName);
        
        for(string file : metadataChunckedFiles){
            System.enqueueJob(new ParseMetadataFile(file,odataSettings));
        }
    }
}