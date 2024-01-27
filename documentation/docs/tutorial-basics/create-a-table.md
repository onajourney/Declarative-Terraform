---
sidebar_position: 2
---

# Create a Table

To create a new table create a file under `resources/dynamodb/`.


```
resources/
└─ dynamodb/
   └─ sample-table.json
```

Which would contain

```json
{
	"name": "SampleTable",
	"hash_key": "id",
	"attributes": [
		{
			"name": "id",
			"type": "S"
		},
		{
			"name": "email",
			"type": "S"
		}
	],
	"gsi": [
		{
			"name": "EmailIndex",
			"hash_key": "email",
			"write_capacity": 5,
			"read_capacity": 5,
			"projection_type": "ALL"
		}
	],
	"stream": {
		"lambda": ["sample"],
		"view_type": "OLD_IMAGE",
		"starting_position": "LATEST"
	}
}
```

`gsi` and `stream` attributes are optional.