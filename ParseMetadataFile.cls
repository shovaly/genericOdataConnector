public  class ParseMetadataFile  implements Queueable {
    private string jsonStr;
    private  final string TYPE_PROPERTY = '$Type';
    private  final integer MAX_PRECISION = 18;
    private  final string MAX_LENGTH_PROPERTY = '$MaxLength';
    private  final string SCALE_PROPERTY = '$Scale';
    private  final string PRECISION_PROPERTY = '$Precision';
    
    
    private Odata_Service_Setting__mdt odataSetting;
    public ParseMetadataFile(string jsonFile,Odata_Service_Setting__mdt odataSetting) {
        this.jsonStr = jsonFile;
        this.odataSetting = odataSetting;
    }
    public void execute(QueueableContext context){
        parseJson();
    }
    private void parseJson(){
        Map<string,List<OdataField>> metadataStructure = new Map<string,List<OdataField>>();
        integer flagStartParse = 0;
        boolean startObject = true;
        boolean startField = true;
        string currentObject = '';
        string currentField = '';
        string prevFieldType = '';
        string prevFieldDescription = '';
        integer prevFieldMaxLength = 0;
        integer prevFieldScale = 0;
        boolean foundField = false;
        JSONParser parser = JSON.createParser(jsonStr);

        while (parser.nextToken() != null) {

                    string getCurrentName = parser.getCurrentName();
                    JSONToken getCurrentToken = parser.getCurrentToken();
                    
                    string getText = parser.getText();
                    if(getCurrentToken == JSONToken.START_OBJECT && getCurrentName == 'Priority.OData')
                    {
                       flagStartParse+=1; 
                       continue;
                    }
                    if(flagStartParse == 1 && getCurrentToken == JSONToken.START_OBJECT) 
                    {
                        flagStartParse+=1;
                    }
                    if(flagStartParse != 2) continue;
                    
                    //start of new object
                    if(getCurrentToken == JSONToken.START_OBJECT && currentObject == ''){
                        currentObject = getCurrentName;
                        metadataStructure.put(currentObject,new List<OdataField>());
                        
                    }
                    else if(getCurrentToken == JSONToken.START_OBJECT){
                      
                        if(!foundField) prevFieldType = 'text';
                      

                        string fieldType = getFieldType(prevFieldType);
                        
                        OdataField odataField = new OdataField(currentField,fieldType,prevFieldDescription);
                        
                        if(fieldType == 'External Lookup'){
                            odataField.lookupTableName = prevFieldType.remove(odataSetting.Lookup_Field_Extension__c + '.').
                            remove(odataSetting.Lookup_Field_Extension__c); 
                        }

                        if(prevFieldMaxLength > 0) odataField.maxLength = prevFieldMaxLength;                  
                        if(prevFieldScale > 0) odataField.scale = prevFieldScale;
                        metadataStructure.get(currentObject).add(odataField);

                        currentField = getCurrentName;
                        foundField = false;
                        prevFieldMaxLength = 0;
                        prevFieldScale = 0;
                    }
                    if(getCurrentName == TYPE_PROPERTY && getText.startsWith('Edm.')){
                        foundField = true;
                        prevFieldType = getText;
                    }
                    if(getCurrentName == TYPE_PROPERTY && getText.startsWith(odataSetting.Lookup_Field_Extension__c)){
                        foundField = true;
                        prevFieldType = getText;
                    }
                    if(getCurrentName == odataSetting.Description_Field__c){
                        prevFieldDescription = getText;
                    }
                  
                    if((getCurrentName == MAX_LENGTH_PROPERTY || 
                        getCurrentName == PRECISION_PROPERTY) && 
                        getText.isNumeric()){
                        Integer precision = integer.valueof(getText);
                        prevFieldMaxLength = precision > MAX_PRECISION ? MAX_PRECISION : precision;
                    }
                    if(getCurrentName == SCALE_PROPERTY  && getText.isNumeric()){
                        prevFieldScale = integer.valueof(getText);
                    }
                    if(getCurrentToken == JSONToken.END_OBJECT && 
                       currentObject == getCurrentName){
                        currentObject = '';
                    }
                   
                }
                insertRecords(metadataStructure);
            }

            private string getFieldType(string prevFieldType){
                if(prevFieldType.startsWith(odataSetting.Lookup_Field_Extension__c)){
                    return 'External Lookup';
                }
                else{
                    return getStandardFieldType(prevFieldType);
                }
            }

            private void  insertRecords(Map<string,List<OdataField>> metadataStructure){

                List<SObject> objectsToInsert = new List<SObject>();
                List<SObject> fieldsToInsert = new List<SObject>();
                

                for (string key : metadataStructure.keySet()) {
                    string externalId = generateRandomString(15);
                    Odata_Object__c objectToInsert = new Odata_Object__c(Name = key,
                    
                    ExternalId__c = externalId);
                    objectsToInsert.add(objectToInsert);


                    List<OdataField> fields = metadataStructure.get(key);
                    for(OdataField field : fields){
                        //todo fix it
                        if(field.fieldName == '') continue;

                        Odata_Field__c fieldToInsert = new Odata_Field__c(Name = field.fieldName,
                        Odata_Object__r = new Odata_Object__c(
                            ExternalId__C = externalId
                        ),
                        Description__c = String.isBlank(field.fieldDescription) ?
                        field.fieldName  :  field.fieldDescription,
                        Field_Type__c = field.fieldType);
                        if(field.maxLength > 0) 
                        {
                            fieldToInsert.Max_Length__c = field.maxLength;
                        }
                        if(field.scale > 0) 
                        {
                            fieldToInsert.Number_Of_Decimal_Digits__c = field.scale;
                        }
                        if(field.fieldType == 'External Lookup'){
                            fieldToInsert.External_Lookup_Table__c = field.lookupTableName;
                        }
                        fieldsToInsert.add(fieldToInsert);
                    }

                    if(fieldsToInsert.size() + objectsToInsert.size() > 1500)
                    {
                        objectsToInsert.addAll(fieldsToInsert);  
                        Id batchJobId = Database.executeBatch(new MetadataParserInsertionBachable(objectsToInsert));
                        objectsToInsert = new List<SObject>(); 
                        fieldsToInsert = new List<SObject>();
                    }

                }

                if(fieldsToInsert.size() + objectsToInsert.size() > 1)
                {
                    objectsToInsert.addAll(fieldsToInsert);  
                    Id batchJobId = Database.executeBatch(new MetadataParserInsertionBachable(objectsToInsert));
                    objectsToInsert = new List<SObject>(); 
                    fieldsToInsert = new List<SObject>();
                }

                objectsToInsert.addAll(fieldsToInsert);


                Id batchJobId = Database.executeBatch(new MetadataParserInsertionBachable(objectsToInsert));

            }

          
            private String generateRandomString(Integer len) {
                final String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz';
                String randStr = '';
                while (randStr.length() < len) {
                   Integer idx = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.length());
                   randStr += chars.substring(idx, idx+1);
                }
                return randStr; 
            }

           
            private string getStandardFieldType(string type){
      

                    if(type == 'text') return 'Text';
                    switch on type {
                        when 'Edm.Int64' {
                            return 'Integer';
                        }
                        when 'Edm.Decimal' {
                            return 'Decimal';
                        }
                        when 'Edm.DateTimeOffset' {
                            return 'DateTime';
                        }
                        when else {
                            return 'Text';
                        }
                    }
            }


}