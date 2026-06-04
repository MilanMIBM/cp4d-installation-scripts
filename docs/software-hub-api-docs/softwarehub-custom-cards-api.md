# Creating custom cards for the home page

You can create custom cards to display key performance indicators on the Software Hub home page with the Custom cards API.

Required role: You must have administration privileges in Software Hub. API authentication uses an authorization token with administration privileges.

Cards give users access to recently used items and an overview of important changes and alerts. The list of available cards is determined by the services that are installed on the platform. You can also add custom cards to the home page with the custom cards API. You can prevent certain cards from being displayed on the home page by disabling them. Each user might see only a subset of the cards based on their permissions and the services that they have access to, so consider how disabling a card affects users with different roles.

You can start with a template to create each of the custom cards that are shown in the following image. See the template types for a description of the templates that were used.

Examples of template types
Figure 1. A collection that shows examples of custom cards
Template types:

The donut template illustrates an array of values as percentages in a donut chart.
The bartemplate creates a two-dimensional bar graph.
The big_number template highlights significant data.
The text_list displays a list of text strings.
The number_list displays a list of numeric values and associated text.
The list displays a list of navigation links. The list can contain headers and associated clickable links.
The content_block displays rows of text or links. Each row can be a paragraph of text or clickable links.

---

## Custom Card Methods

Get a list of custom cards
Retrieves the properties for the custom cards that you can update.

GET /zen-data/v1/custom_cards

Request
Custom Headers
Authorization
string
Authorization: ZenApiKey | Bearer ``<token>``

Examples:

Authorization: ZenApiKey ``<token>``

Authorization: Bearer `<token>`

Example request
curl -k -X GET 'https://{cpd_cluster_host}/zen-data/v1/custom_cards' -H 'Accept-Language: en-US' -H 'Accept: application/json' -H 'Authorization: ZenApiKey {TOKEN}'

Response
Response Body
SuccessGetResponseV2
_messageCode_
string
Message code.

message
string
Message

status
string
Status.

data
object
Status Code
200
Success.

401
Unauthorized.

404
Not Found.

500
Internal Server Error.

Example responses

Status 200
{
  "_messageCode_": "success",
  "message": "Successfully retrieved custom cards",
  "data": {}
}

Create or replace a custom card
Creates a custom card or replaces an existing custom card. You must include the card definition as a JSON string in the HTTP request body. The definition specifies the structure and the content of the card.

PUT /zen-data/v1/custom_cards/{key}

Request
Custom Headers
Authorization
string
Authorization: ZenApiKey | Bearer `<token>`

Examples:

Authorization: ZenApiKey `<token>`

Authorization: Bearer `<token>`
Path Parameters
key
Required*
string
The name of the card that you want to create or replace. The string must be unique. If a custom card with the specified key does not exist, the custom card is created, otherwise the existing custom card is replaced.

Request Body
Required*
CustomCardReplaceObject
Update role object.

permissions
Required*
string[]
Specifies the permissions that a user needs to see the card. The array must have at least one permission. If the array has no permissions parameter, the card is shown to everyone. It is an array of user permissions from the Software Hub platform.

order
Required*
integer
Defines the position of the card. The value must be in the range 1 - 50.

Possible values: 1 ≤ value ≤ 50

Example: 1

title
Required*
string
The display name for the card. The string must be 40 characters or less.

Example: Disk usage

template_type
Required*
string
Defines the display type of the card. The template_type parameter must be one of the following: bar, big_number, content_block, donut, list, number_list, text_list).

Example: big_number

roles
string[]
An array of authorized roles from Software Hub platform that shows the card to a user having any of the listed roles.

data_url
string
Provides data to the card. You must provide either a data_url object or a data object. The data object is an object that populates data in the card. The properties of the object must match the type of template defined. The expected structure for each template_type parameter is in the examples.

drilldown_url
string
Defines the URL that the user navigates to when they click "View details". If this parameter is not defined, the card does not display a "View details" link.

description
string
Helps users understand the purpose of the card. The string must be 200 characters or less.

Example: The card gives details about loans and deposits

service_defined_id
string
Identifiers that can be defined by the services for use in their UI components.

Example: 566c3a42-610c-48e8-a879-9b175b7a52cc

window_open_target
string
Specifies the target attribute or the name of the window. The following values are supported: empty or not provided (the URL gets loaded on the current page by default), _blank (URL is loaded into a new window or tab every time), name (the name of the window where the URL is loaded and the name does not specify the title of the new window).

Example: <https://foo.bar>

refresh_rate
integer
The interval in seconds at which the content is refreshed by the source.

Default: 0

Example: 5

data

CardObject

list_data

ListDataObj

rows
Required*
An array of table rows.

object[]

any property
headers
Required*
string[]
An array of table headers.

donut_data

DonutDataObj

data_array
Required*
An array of group-value objects.

object[]

group
Required*
string
value
Required*
number
center_label
Required*
string
Label to be displayed in the center of the donut chart.

bar_data

BarDataObj

data_array
Required*
An array of group-value objects.

object[]

group
Required*
string
value
Required*
number
x_axis_label
Required*
string
X axis label.

y_axis_label
Required*
string
Y axis label.

number_list_data

NumberListDataObj

rows
Required*

object[]

label
Required*
string
The label in the row.

Example: Total approved packages

value
Required*
string
The big text in the row.

Example: 25k

drilldown_url
string
The link where the user should navigate after clicking the row.

Example: /zen/#/openSource/packages

text_list_data

TextListDataObj

rows
Required*

object[]

label
Required*
string
The label in the row.

Example: Data virtualization

sub_text
Required*
string
The small text in the row.

Example: Increase since last month

drilldown_url
string
The link where the user should navigate after clicking the row.

Example: /zen/#/openSource/packages

big_number_data

BigNumberDataObj

metric
Required*
string
Value of the Card.

Example: $55B

sub_text
Required*
string
A small description about the metric.

Example: Increase since last month

prefix
string
Icon from the carbon icons library.

Example: ArrowUp32

suffix
string
Suffix of the metric that'll be smaller than the metric.

Example: %

footer_1
string
A small description about the metric.

Example: 867 Total vulnerabilities

footer_2
string
A small description about the metric.

Example: AskPQL 2.3 package most at risk

content_block_data

ContentBlockDataObj

rows
Required*
An array of content blocks.

object[]

type
Required*
string
The type of field, example, text or link.

content
Required*
string
Content of the row.

nav_url
string
Link to navigate to after clicking the row.

window_open_target
string
Target window for nav_url

Example request
curl -k -X PUT 'https://{cpd_cluster_host}/zen-data/v1/custom_cards' -H 'Accept-Language: en-US' -H 'Accept: application/json' -H 'Authorization: ZenApiKey {TOKEN}'
-d '{
    "permissions": ["manage_catalog"],
    "order": 1,
    "title": "Disk usage",
    "template_type": "big_number",
    "data": {      "big_number_data": {
          "metric":  "55",
          "sub_text": "Increase since last month",
          "prefix": "ArrowUp32",
          "suffix": "%",
          "footer_1": "867 Total vulnerabilities",
          "footer_2": "AskPQL 2.3 package most at risk"
        }
      }
  }'

Response
Response Body
object
_messageCode_
string
Message code.

message
string
Message.

data
object
Status Code
200
Success.

400
Bad Request.

401
Unauthorized.

403
Forbidden.

404
Not Found.

500
Internal Server Error.

Example responses

Status 200
{
  "_messageCode_": "success",
  "data": {
    "id": 537163840404062200,
    "name": "os_vulnerabilities",
    "title": "Open source vulnerabilities",
    "description": "",
    "drilldown_url": "",
    "order": 12,
    "template_type": "big_number",
    "data_url": "",
    "empty_state": {},
    "source_url": "",
    "refresh_rate": 0,
    "data": {
      "big_number_data": {
        "metric": 55,
        "sub_text": "Increase since last month",
        "prefix": "ArrowUp32",
        "suffix\"": "%",
        "footer_1": "867 Total vulnerabilities",
        "footer_2": "AskPQL 2.3 package most at risk"
      }
    }
  }
}

Update an existing card
Updates the information that is displayed on an existing card.

PATCH /zen-data/v1/custom_cards/{key}

Request
Custom Headers
Authorization
string
Authorization: ZenApiKey | Bearer `<token>`

Examples:

Authorization: ZenApiKey `<token>`

Authorization: Bearer `<token>`
Path Parameters
key
Required*
string
The name of the card that you want to update.

Request Body
Required*
CustomCardUpdateObject
Update role object.

permissions
string[]
Specifies the permissions that a user needs to see the card. The array must have at least one permission. If the array has no permissions parameter, the card is shown to everyone. It is an array of user permissions from the Software Hub platform.

roles
string[]
An array of user roles from Software Hub platform.

order
integer
Defines the position of the card. The value must be in the range 1 - 50.

Possible values: 1 ≤ value ≤ 50

Example: 2

title
string
The display name for the card. The string must be 40 characters or less.

Example: Disk usage

template_type
string
Defines the display type of the card. The template_type parameter must be one of the following: bar, big_number, content_block, donut, list, number_list, text_list).

Example: donut

data_url
string
Provides data to the card. You must provide either a data_url object or a data object. The data object is an object that populates data in the card. The properties of the object must match the type of template defined. The expected structure for each template_type parameter is in the examples.

drilldown_url
string
Defines the URL that the user navigates to when they click View details. If this parameter is not defined, the card does not display a "View details" link.

description
string
Helps users understand the purpose of the card. The string must be 200 characters or less.

service_defined_id
string
identifiers that can be defined by the services for use in their UI components.

Example: 566c3a42-610c-48e8-a879-9b175b7a52cc

window_open_target
string
Specifies the target attribute or the name of the window. The following values are supported: empty or not provided (the URL gets loaded on the current page by default), _blank (URL is loaded into a new window or tab every time), name (the name of the window where the URL is loaded and the name does not specify the title of the new window).

Example: <https://foo.bar>

refresh_rate
integer
The interval in seconds at which the content is refreshed by the source.

Default: 0

Example: 5

data

CardObject

list_data

ListDataObj

rows
Required*
An array of table rows.

object[]

any property
headers
Required*
string[]
An array of table headers.

donut_data

DonutDataObj

data_array
Required*
An array of group-value objects.

object[]

group
Required*
string
value
Required*
number
center_label
Required*
string
Label to be displayed in the center of the donut chart.

bar_data

BarDataObj

data_array
Required*
An array of group-value objects.

object[]

group
Required*
string
value
Required*
number
x_axis_label
Required*
string
X axis label.

y_axis_label
Required*
string
Y axis label.

number_list_data

NumberListDataObj

rows
Required*

object[]

label
Required*
string
The label in the row.

Example: Total approved packages

value
Required*
string
The big text in the row.

Example: 25k

drilldown_url
string
The link where the user should navigate after clicking the row.

Example: /zen/#/openSource/packages

text_list_data

TextListDataObj

rows
Required*

object[]

label
Required*
string
The label in the row.

Example: Data virtualization

sub_text
Required*
string
The small text in the row.

Example: Increase since last month

drilldown_url
string
The link where the user should navigate after clicking the row.

Example: /zen/#/openSource/packages

big_number_data

BigNumberDataObj

metric
Required*
string
Value of the Card.

Example: $55B

sub_text
Required*
string
A small description about the metric.

Example: Increase since last month

prefix
string
Icon from the carbon icons library.

Example: ArrowUp32

suffix
string
Suffix of the metric that'll be smaller than the metric.

Example: %

footer_1
string
A small description about the metric.

Example: 867 Total vulnerabilities

footer_2
string
A small description about the metric.

Example: AskPQL 2.3 package most at risk

content_block_data

ContentBlockDataObj

rows
Required*
An array of content blocks.

object[]

type
Required*
string
The type of field, example, text or link.

content
Required*
string
Content of the row.

nav_url
string
Link to navigate to after clicking the row.

window_open_target
string
Target window for nav_url

Example request
curl -k -X PATCH 'https://{cpd_cluster_host}/zen-data/v1/custom_cards/disk_usage_donut' -H 'Accept-Language: en-US' -H 'Accept: application/json' -H 'Authorization: ZenApiKey {TOKEN}'
-d '{
    "title": "Disk usage"
  }'

Response
Response Body
SuccessPostResponseWithObjV2
_messageCode_
string
Message code.

message
string
Message.

data
object
Status Code
200
Success.

400
Bad Request.

401
Unauthorized.

403
Forbidden.

404
Not Found.

500
Internal Server Error.

Example responses

Status 200
{
  "_messageCode_": "success",
  "message": "Successfully edited custom card",
  "data": {
    "id": 1,
    "name": "homepage_card_disk_usage",
    "title": "Disk usage",
    "description": "",
    "drilldown_url": "/zen/#/v1/diskUsage",
    "order": 2,
    "template_type": "donut",
    "data_url": "/v1/homepage/diskUsage",
    "empty_state": {},
    "source_url": "",
    "refresh_rate": 0,
    "data": null
  }
}

Delete a custom card
Deletes an existing card with the specified key.

DELETE /zen-data/v1/custom_cards/{key}

Request
Custom Headers
Authorization
string
Authorization: ZenApiKey | Bearer `<token>`

Examples:

Authorization: ZenApiKey `<token>`

Authorization: Bearer `<token>`
Path Parameters
key
Required*
string
The name of the custom card that you want to delete.

Example request
curl -k -X DELETE 'https://{cpd_cluster_host}/zen-data/v1/custom_cards/os_vulnerabilities' -H 'Accept-Language: en-US' -H 'Accept: application/json' -H 'Authorization: ZenApiKey {TOKEN}'

Response
Response Body
successResponse
_messageCode_
string
The identifier of the response.

message
string
The explanation of the _messageCode_.

Status Code
200
Success.

400
Bad Request.

401
Unauthorized.

403
Forbidden.

404
Not Found.

500
Internal Server Error.

Example responses

Status 200
{
  "_messageCode_": "success",
  "message": "Successfully deleted custom card"
}
