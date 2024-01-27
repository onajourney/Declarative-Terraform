---
sidebar_position: 1
---

# Create a Lambda

To create a new lambda function create a folder under `resources/lambda/`.

```
resources/
└─ lambda/
   └─ function-name/
      ├─ config.json
      └─ index.js
```

At a bare minimun you only need `index.js` which contains your lambda code. This is the default handler in FS Terraform.

```js
exports.handler = async (event) => {
	console.log('Lambda function code', event);
};
```

If you lambda funtion has package dependencies you can include a barebones `package.json` file in the lambda folder.

```json
{
	"type": "module",
	"dependencies": {
		"dependency": "^1.0.0"
	}
}
```

FS Terraform will automatically handle package installation (using the npm_install helper) and zipping for you when you deploy. This is done outside of the lambda folder to keep your working directory clean.  

You can override module defaults (including the handler) by providing a config.json file.

```json
{
	"Runtime": "nodejs14.x",
	"Handler": "index.handler",
	"MemorySize": 256,
	"Timeout": 5,
	"Environment": {
		"Variables": {
			"EXAMPLE_VARIABLE": "value"
		}
	}
}
```

You can also use this file to provide Environment variables if needed.