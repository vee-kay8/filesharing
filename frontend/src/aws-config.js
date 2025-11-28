// AWS Configuration for Amplify
const awsConfig = {
  Auth: {
    Cognito: {
      userPoolId: 'us-east-1_kirtpO01n',
      userPoolClientId: '71d9sbqv6ghee4qad5p08v2574',
      region: 'us-east-1',
      loginWith: {
        email: true
      }
    }
  },
  API: {
    REST: {
      FileShareAPI: {
        endpoint: 'https://qopf2wt9g7.execute-api.us-east-1.amazonaws.com/v1',
        region: 'us-east-1'
      }
    }
  }
};

export default awsConfig;
