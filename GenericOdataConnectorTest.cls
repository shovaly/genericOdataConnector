@istest
public class GenericOdataConnectorTest {
   

    @istest
    public static void getAuthenticationCapabilitiesTest(){
        GenericOdataConnector connector = new GenericOdataConnector();
        List<DataSource.AuthenticationCapability>  cap = connector.getAuthenticationCapabilities();
        System.assertEquals(cap.size(),1);
    }

    @istest
    public static void getCapabilitiesTest(){
        GenericOdataConnector connector = new GenericOdataConnector();
        List<DataSource.Capability>  cap = connector.getCapabilities();
        System.assertEquals(cap.size(),3);
    }

    @istest
    public static void getConnectionTest(){
        GenericOdataConnector connector = new GenericOdataConnector();
        DataSource.ConnectionParams connParam = new  DataSource.ConnectionParams();
        connParam.username = 'testUser';
        connector.getConnection(connParam);

    }
}