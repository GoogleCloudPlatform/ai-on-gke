# swagger_client.SDKApi

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**allocate**](SDKApi.md#allocate) | **POST** /allocate | Call to self Allocation the GameServer
[**get_game_server**](SDKApi.md#get_game_server) | **GET** /gameserver | Retrieve the current GameServer data
[**health**](SDKApi.md#health) | **POST** /health | Send a Empty every d Duration to declare that this GameSever is healthy
[**ready**](SDKApi.md#ready) | **POST** /ready | Call when the GameServer is ready
[**reserve**](SDKApi.md#reserve) | **POST** /reserve | Marks the GameServer as the Reserved state for Duration
[**set_annotation**](SDKApi.md#set_annotation) | **PUT** /metadata/annotation | Apply a Annotation to the backing GameServer metadata
[**set_label**](SDKApi.md#set_label) | **PUT** /metadata/label | Apply a Label to the backing GameServer metadata
[**shutdown**](SDKApi.md#shutdown) | **POST** /shutdown | Call when the GameServer is shutting down
[**watch_game_server**](SDKApi.md#watch_game_server) | **GET** /watch/gameserver | Send GameServer details whenever the GameServer is updated


# **allocate**
> SdkEmpty allocate(body)

Call to self Allocation the GameServer

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkEmpty() # SdkEmpty | 

try:
    # Call to self Allocation the GameServer
    api_response = api_instance.allocate(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->allocate: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkEmpty**](SdkEmpty.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **get_game_server**
> SdkGameServer get_game_server()

Retrieve the current GameServer data

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()

try:
    # Retrieve the current GameServer data
    api_response = api_instance.get_game_server()
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->get_game_server: %s\n" % e)
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SdkGameServer**](SdkGameServer.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **health**
> SdkEmpty health(body)

Send a Empty every d Duration to declare that this GameSever is healthy

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkEmpty() # SdkEmpty |  (streaming inputs)

try:
    # Send a Empty every d Duration to declare that this GameSever is healthy
    api_response = api_instance.health(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->health: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkEmpty**](SdkEmpty.md)|  (streaming inputs) | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **ready**
> SdkEmpty ready(body)

Call when the GameServer is ready

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkEmpty() # SdkEmpty | 

try:
    # Call when the GameServer is ready
    api_response = api_instance.ready(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->ready: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkEmpty**](SdkEmpty.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **reserve**
> SdkEmpty reserve(body)

Marks the GameServer as the Reserved state for Duration

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkDuration() # SdkDuration | 

try:
    # Marks the GameServer as the Reserved state for Duration
    api_response = api_instance.reserve(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->reserve: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkDuration**](SdkDuration.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **set_annotation**
> SdkEmpty set_annotation(body)

Apply a Annotation to the backing GameServer metadata

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkKeyValue() # SdkKeyValue | 

try:
    # Apply a Annotation to the backing GameServer metadata
    api_response = api_instance.set_annotation(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->set_annotation: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkKeyValue**](SdkKeyValue.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **set_label**
> SdkEmpty set_label(body)

Apply a Label to the backing GameServer metadata

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkKeyValue() # SdkKeyValue | 

try:
    # Apply a Label to the backing GameServer metadata
    api_response = api_instance.set_label(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->set_label: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkKeyValue**](SdkKeyValue.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **shutdown**
> SdkEmpty shutdown(body)

Call when the GameServer is shutting down

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()
body = swagger_client.SdkEmpty() # SdkEmpty | 

try:
    # Call when the GameServer is shutting down
    api_response = api_instance.shutdown(body)
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->shutdown: %s\n" % e)
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **body** | [**SdkEmpty**](SdkEmpty.md)|  | 

### Return type

[**SdkEmpty**](SdkEmpty.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **watch_game_server**
> StreamResultOfSdkGameServer watch_game_server()

Send GameServer details whenever the GameServer is updated

### Example
```python
from __future__ import print_function
import time
import swagger_client
from swagger_client.rest import ApiException
from pprint import pprint

# create an instance of the API class
api_instance = swagger_client.SDKApi()

try:
    # Send GameServer details whenever the GameServer is updated
    api_response = api_instance.watch_game_server()
    pprint(api_response)
except ApiException as e:
    print("Exception when calling SDKApi->watch_game_server: %s\n" % e)
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**StreamResultOfSdkGameServer**](StreamResultOfSdkGameServer.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

