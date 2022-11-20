public with sharing class MetadataParserSelector {
    public MetadataParserSelector() {

    }

    public void DeletePrevRecords(){
        Odata_Object__c[] odataObjects = [SELECT Id FROM Odata_Object__c]; 
             delete odataObjects; 
    }

    public string getTableExternField(string tableName){
        return [SELECT External_Id_Column__c FROM Odata_Object__c where Name =: tableName Limit 1].External_Id_Column__c;
    }

    public User getPriorityEndpointForUser(string userName){
        User u =  [SELECT AboutMe  FROM User where id = :Userinfo.getUserId() Limit 1];
        return u;
    }

    public SET<String> getTableFields(string tableName){

        SET<String> fields = new SET<String>();
        for(Odata_Field__c field : [SELECT Name FROM Odata_Field__c where Odata_Object__r.Name =: tableName]) {
            fields.add(field.Name);
        }
        return fields;
    }

 

    public List<Odata_Field__c> GetActiveOdataObjectsAndFields(){

        List<Odata_Field__c> odataFields = [SELECT External_Lookup_Table__c ,Max_Length__c,Number_Of_Decimal_Digits__c, Odata_Object__r.Name,Odata_Object__c,Description__c,
        Name,Field_Type__c FROM Odata_Field__c
         Where Include_Field__c = true AND Odata_Object__r.Include_Object__c = true
           ORDER BY Odata_Object__c]; 
        return odataFields;
    }

    public Odata_Service_Setting__mdt GetOdataSettings(string externalDataSourceName){
        Odata_Service_Setting__mdt setting = [Select Description_Field__c,Lookup_Field_Extension__c from Odata_Service_Setting__mdt  
        where DeveloperName =: externalDataSourceName LIMIT 1]; 
        return setting;
    }
    

    public List<string> GetMetadataContent(string externalDataSourceName){

        List<string> metadataChunkFiles = new List<string>();
        OData_Source__c sourceName = [Select Id from OData_Source__c  
                where ExsternalDatasourceName__c =: externalDataSourceName LIMIT 1]; 
        
        List<id> linksIds =new List<id>();
        for(ContentDocumentLink link : [SELECT ContentDocumentId FROM ContentDocumentLink where LinkedEntityId =: sourceName.Id]){
            linksIds.add(link.ContentDocumentId);
        }
        
        for(ContentVersion content : 
            [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId in :linksIds AND IsLatest = true ])
        {
            metadataChunkFiles.add(content.VersionData.toString());
        }                            

        return metadataChunkFiles;
    }
}