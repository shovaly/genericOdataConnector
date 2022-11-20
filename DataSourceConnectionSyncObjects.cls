public with sharing class DataSourceConnectionSyncObjects {
    private MetadataParserSelector parserSelector;
    private final integer NUMERIC_MAX_LENGTH = 18;

    public DataSourceConnectionSyncObjects() {
        
        this.parserSelector = new MetadataParserSelector();
    }

    public List<DataSource.Table> sync() {
        List<DataSource.Table> tables = new List<DataSource.Table>();
        
        List<Odata_Field__c> fields = parserSelector.GetActiveOdataObjectsAndFields();
        if(fields.size() == 0) return tables; 
        string currentObjectId = fields[0].Odata_Object__c;
        string currentObjectName = fields[0].Odata_Object__r.Name;
        List<DataSource.Column> columns = new List<DataSource.Column>();
        Map<String,List<DataSource.Column >> lookupFields = new Map<String,List<DataSource.Column >>();
        for(Odata_Field__c field : fields){
            if(currentObjectId != field.Odata_Object__c)
            {
                columns.add(DataSource.Column.text('ExternalId', 255));
                columns.add(DataSource.Column.url('DisplayUrl'));

                tables.add(DataSource.Table.get(currentObjectName
                , currentObjectName, columns));
                columns = new List<DataSource.Column>();
                currentObjectName = field.Odata_Object__r.Name;
                currentObjectId = field.Odata_Object__c;
            }
            DataSource.Column selectedColumn = getRelevanyColumn(field);
            if(selectedColumn.type == DataSource.DataType.EXTERNAL_LOOKUP_TYPE)
            {
                if(lookupFields.get(field.External_Lookup_Table__c) == null)
                {
                    lookupFields.put(field.External_Lookup_Table__c, new List<DataSource.Column>{selectedColumn});
                }
                
                lookupFields.get(field.External_Lookup_Table__c).add(selectedColumn);
                
            }
            else{
                columns.add(selectedColumn);
            }
        }

        columns.add(DataSource.Column.text('ExternalId', 255));
        columns.add(DataSource.Column.url('DisplayUrl'));
        tables.add(DataSource.Table.get(currentObjectName, currentObjectName, columns));

        for (string key : lookupFields.keySet()) {
            for(DataSource.Table tbl : tables)
            {
                if (key == tbl.name) {
                    List<DataSource.Column> lookUpcolumns = lookupFields.get(key);
                    system.debug('###lookUpcolumns' + lookUpcolumns);
                    tbl.columns.addAll(lookUpcolumns);
                    
                }

            }
        }

        return tables;
    }

    private DataSource.Column getRelevanyColumn(Odata_Field__c field)
    {
       
        switch on field.Field_Type__c {
            when 'Text' {
                DataSource.Column column =  DataSource.Column.text(field.Name,field.Description__c, 255);
                if(field.Max_Length__c > 0){
                    column.length =  integer.valueOf(field.Max_Length__c);
                }
                return column;
            }
            when 'Integer' {
                DataSource.Column column =  DataSource.Column.integer(field.Name,NUMERIC_MAX_LENGTH);
                if(field.Max_Length__c > 0 && field.Max_Length__c < NUMERIC_MAX_LENGTH){
                    column.length =  integer.valueOf(field.Max_Length__c);
                }
                column.decimalPlaces = 0;
                
                column.label = field.Description__c != null ? field.Description__c : field.name;
                
                return column;
            }
            when 'Decimal' {
                DataSource.Column column =  DataSource.Column.number(field.Name,NUMERIC_MAX_LENGTH, 2);
                column.label = field.Description__c != null ? field.Description__c : field.name;
                if(field.Max_Length__c > 0){
                    column.length =  integer.valueOf(field.Max_Length__c);
                }
                if(field.Number_Of_Decimal_Digits__c > 0)
                {
                    column.decimalPlaces = integer.valueOf(field.Number_Of_Decimal_Digits__c);
                }
                return column;
            }
            when 'External Lookup' {
                DataSource.Column column =  DataSource.Column.externalLookup(field.Name,field.Odata_Object__r.Name);
                column.label = field.Description__c != null ? field.Description__c : field.name;
                
                return column;
            }

            when else {
                return DataSource.Column.text(field.Name,field.Description__c, 255);

            }
        }
    }
}