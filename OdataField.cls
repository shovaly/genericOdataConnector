public  class OdataField {
    public string fieldName {get;set;}
    public string fieldType {get;set;}
    public string lookupTableName {get;set;}
    public string fieldDescription {get;set;}
    public integer scale {get;set;}
    public integer maxLength {get;set;}

   
    public OdataField(string fieldName,string fieldType,string fieldDescription){
        this.fieldName = fieldName;
        this.fieldType = fieldType;
        this.fieldDescription = fieldDescription;
    }

 

}