public with sharing class MetadataUtils {
    
    public static dynamic_apex_execution__mdt getRelevantMetadaData(Map<string,Object> response){
            string formType = (string)response.get('FormType');
            List<dynamic_apex_execution__mdt> record = [Select Id,Apex_Class__c from dynamic_apex_execution__mdt
            where field_value_condition__c =: formType AND
            field_condition__c =: 'FormType'];
            return record[0];
    }
}
