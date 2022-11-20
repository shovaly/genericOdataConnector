global class MetadataParserInsertionBachable implements Database.Batchable<sObject>  {

    List<SObject> recordList;
    global MetadataParserInsertionBachable(List<SObject> recordList) {
        this.recordList = recordList;
    }


    global Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator('SELECT Id FROM OData_Source__c');
     }
  
     global void execute(Database.BatchableContext BC, List<sObject> scope){
        if (recordList == null || recordList.isEmpty()) { return; }
        Database.SaveResult[] results = Database.insert(recordList,true);
     }
  
     global void finish(Database.BatchableContext BC){
     }
}