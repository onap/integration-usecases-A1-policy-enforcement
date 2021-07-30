package org.onap.ccsdk.cds.blueprintsprocessor.services.execution.scripts

/*
* Copyright © 2019 TechMahindra
* Author: Malinconico Aniello Paolo, Vamshi Namilikonda, Thamlur Raju
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.databind.node.ObjectNode
import java.io.File
import java.nio.file.Path
import java.nio.file.Paths
import org.apache.commons.io.IOUtils
import org.apache.http.client.ClientProtocolException
import org.apache.http.client.entity.EntityBuilder
import org.apache.http.client.methods.HttpPost
import org.apache.http.client.methods.HttpUriRequest
import org.apache.http.message.BasicHeader
import org.onap.ccsdk.cds.blueprintsprocessor.core.api.data.ExecutionServiceInput
import org.onap.ccsdk.cds.blueprintsprocessor.rest.BasicAuthRestClientProperties
import org.onap.ccsdk.cds.blueprintsprocessor.rest.service.BasicAuthRestClientService
import org.onap.ccsdk.cds.blueprintsprocessor.rest.service.BlueprintWebClientService
import org.onap.ccsdk.cds.blueprintsprocessor.rest.service.RestLoggerService
import org.onap.ccsdk.cds.blueprintsprocessor.services.execution.AbstractScriptComponentFunction
import org.onap.ccsdk.cds.controllerblueprints.core.BlueprintProcessorException
import org.onap.ccsdk.cds.controllerblueprints.core.utils.ArchiveType
import org.onap.ccsdk.cds.controllerblueprints.core.utils.BlueprintArchiveUtils
import org.onap.ccsdk.cds.controllerblueprints.core.utils.JacksonUtils
import org.slf4j.LoggerFactory
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpMethod
import org.springframework.http.MediaType
import org.yaml.snakeyaml.Yaml
import java.io.IOException
import java.util.Base64
import java.nio.charset.Charset
import java.nio.file.Files
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import org.onap.ccsdk.cds.blueprintsprocessor.functions.resource.resolution.storedContentFromResolvedArtifactNB

open class DayOneConfig : AbstractScriptComponentFunction() {

    private val log = LoggerFactory.getLogger(DayOneConfig::class.java)!!

    override fun getName(): String {
        return "DayOneConfig"
    }

    override suspend fun processNB(executionRequest: ExecutionServiceInput) {
        log.info("DAY-1 Script excution Started")

        val baseK8sApiUrl = getDynamicProperties("api-access").get("url").asText()
        val k8sApiUsername = getDynamicProperties("api-access").get("username").asText()
        val k8sApiPassword = getDynamicProperties("api-access").get("password").asText()

        log.info("Multi-cloud params $baseK8sApiUrl")

        val aaiApiUrl = getDynamicProperties("aai-access").get("url").asText()
        val aaiApiUsername = getDynamicProperties("aai-access").get("username").asText()
        val aaiApiPassword = getDynamicProperties("aai-access").get("password").asText()

        log.info("AAI params $aaiApiUrl")

        val vnfID: String = getDynamicProperties("vnf-id-value").asText()

        log.info("Get vnfID $vnfID")

        val vnfUrl = aaiApiUrl + "/aai/v19/network/generic-vnfs/generic-vnf/" + vnfID + "/vf-modules"

        val mapOfHeaders = hashMapOf<String, String>()
        mapOfHeaders.put("Accept", "application/json")
        mapOfHeaders.put("Content-Type", "application/json")
        mapOfHeaders.put("x-FromAppId", "SO")
        mapOfHeaders.put("X-TransactionId", "get_aai_subscr")
        val basicAuthRestClientProperties: BasicAuthRestClientProperties = BasicAuthRestClientProperties()
        basicAuthRestClientProperties.username = aaiApiUsername
        basicAuthRestClientProperties.password = aaiApiPassword
        basicAuthRestClientProperties.url = vnfUrl
        basicAuthRestClientProperties.additionalHeaders = mapOfHeaders
        val basicAuthRestClientService: BasicAuthRestClientService = BasicAuthRestClientService(basicAuthRestClientProperties)
        try {
            val resultOfGet: BlueprintWebClientService.WebClientResponse<String> = basicAuthRestClientService.exchangeResource(HttpMethod.GET.name, "", "")

            val aaiBody = resultOfGet.body
            val aaiPayloadObject = JacksonUtils.jsonNode(aaiBody) as ObjectNode

            for (item in aaiPayloadObject.get("vf-module")) {

                log.info("item payload Deatils : $item")

                val vfModuleID: String = item.get("vf-module-id").asText()
                log.info("AAI Vf-module ID is : $vfModuleID")

                val vfModuleInvariantID: String = item.get("model-invariant-id").asText()
                log.info("AAI Vf-module Invariant ID is : $vfModuleInvariantID")

                val vfModuleUUID: String = item.get("model-version-id").asText()
                log.info("AAI Vf-module UUID is : $vfModuleUUID")

                val vfModuleInstance: String = item.get("heat-stack-id").asText()
                log.info("AAI Vf-module Heat Stack ID : $vfModuleInstance")

                var delimiter = "/"

                val Instance = vfModuleInstance.split(delimiter)
                val instanceName = Instance[0]
                val instanceID = Instance[1]
                log.info("instance name is : $instanceName")
                log.info("K8S instance ID is : $instanceID")

                val typOfVfmodule = "cnf"
                log.info("Type of vf-module: $typOfVfmodule")

                val k8sRbProfileName = "default"

                val k8sConfigTemplateName = "template_$vfModuleID"

                val api = K8sConfigTemplateApi(k8sApiUsername, k8sApiPassword, baseK8sApiUrl, vfModuleInvariantID, vfModuleUUID, k8sConfigTemplateName)

                // Check if definition exists
                if (!api.hasDefinition()) {
                    throw BlueprintProcessorException("K8s Config Template ($vfModuleInvariantID/$vfModuleUUID) -  $k8sConfigTemplateName not found ")
                }

                log.info("Config Template name: $k8sConfigTemplateName")

                val configmapName = "res-default-a1-pe-simulator-app-cm"
                log.info("configmap retrieved " + typOfVfmodule + " vfmodule -> " + configmapName)
                modifyTemplate(configmapName, typOfVfmodule)

                var configTemplate = K8sConfigTemplate()
                configTemplate.templateName = k8sConfigTemplateName
                configTemplate.description = " "
                configTemplate.ChartName = typOfVfmodule
                log.info("Chart name: ${configTemplate.ChartName}")

                if (!api.hasConfigTemplate(configTemplate)) {
                    log.info("K8s Config Template Upload Started")
                    api.createConfigTemplate(configTemplate)
                    val configTemplateFile: Path = prepareConfigTemplateJson()
                    api.uploadConfigTemplateContent(configTemplate, configTemplateFile)
                    log.info("K8s Config Template Upload Completed")
                    val configName = "config_1"
                    val config = K8sConfigPayloadJson()
                    config.configName = configName
                    config.templateName = k8sConfigTemplateName
                    log.info("Get ves, ues, cells from CDS")
                    config.values.topic.ves = getVes()
                    config.values.topic.ues = getUes()
                    config.values.topic.cells = getCells()

                    log.info("config $config.values.topic")

                    api.createOrUpdateConfig(config, k8sRbProfileName)
                }
            }
            log.info("DAY-1 Script excution completed")
        } catch (e: Exception) {
            log.info("Caught exception trying to get the vnf Details!!")
        }
    }

    suspend fun getUes(): String {
        val resolutionKey = getDynamicProperties("resolution-key").asText()

        val ues = storedContentFromResolvedArtifactNB(resolutionKey, "ues")
        log.info("ues: $ues")

        return ues
    }

    suspend fun getVes(): String {
        val resolutionKey = getDynamicProperties("resolution-key").asText()

        val ves = storedContentFromResolvedArtifactNB(resolutionKey, "ves")
        log.info("ves: $ves")

        return ves
    }

    suspend fun getCells(): String {
        val resolutionKey = getDynamicProperties("resolution-key").asText()

        val cells = storedContentFromResolvedArtifactNB(resolutionKey, "cells")
        log.info("cells: $cells")

        return cells
    }

    fun prepareConfigTemplateJson(): Path {
        val bluePrintContext = bluePrintRuntimeService.bluePrintContext()
        val bluePrintBasePath: String = bluePrintContext.rootPath

        var profileFilePath: Path = Paths.get(bluePrintBasePath.plus(File.separator).plus("Templates").plus(File.separator).plus("k8s-profiles").plus(File.separator).plus("cnf-config-template.tar.gz"))
        log.info("Reading K8s Config Template file: $profileFilePath")

        val profileFile = profileFilePath.toFile()

        if (!profileFile.exists())
            throw BlueprintProcessorException("K8s Profile template file $profileFilePath does not exists")

        return profileFilePath
    }

    override suspend fun recoverNB(runtimeException: RuntimeException, executionRequest: ExecutionServiceInput) {
        log.info("Executing Recovery")
        bluePrintRuntimeService.getBlueprintError().addError("${runtimeException.message}", "recoverNB")
    }

    fun modifyTemplate(configmapName: String, typOfVfmodule: String): String {

        log.info("Executing modifyTemplate ->")

        val bluePrintContext = bluePrintRuntimeService.bluePrintContext()
        val bluePrintBasePath: String = bluePrintContext.rootPath

        val destPath: String = "/tmp/config-template-" + typOfVfmodule

        var templateFilePath: Path = Paths.get(bluePrintBasePath.plus(File.separator).plus("Templates").plus(File.separator).plus("k8s-profiles").plus(File.separator).plus("cnf-config-template.tar.gz"))

        log.info("Reading config template file: $templateFilePath")
        val templateFile = templateFilePath.toFile()

        if (!templateFile.exists())
            throw BlueprintProcessorException("K8s Profile template file $templateFilePath does not exists")

        log.info("Decompressing config template to $destPath")

        val decompressedProfile: File = BlueprintArchiveUtils.deCompress(
                templateFilePath.toFile(),
                "$destPath", ArchiveType.TarGz
        )

        log.info("$templateFilePath decompression completed")

        // Here we update override.yaml file

        val manifestFileName = destPath.plus(File.separator).plus(typOfVfmodule).plus(File.separator).plus("templates").plus(File.separator).plus("configmap.yaml")
        log.info("Modification of configmap.yaml file at $manifestFileName")
        var finalManifest = ""
        File(manifestFileName).bufferedReader().use { inr ->
            try {
                val manifestYaml = Yaml()
                val manifestObject: Map<String, Any> = manifestYaml.load(inr)

                for ((k, v) in manifestObject) {
                    log.info("manifestObject: $k, $v")
                }

                log.info("Uploaded YAML object")

                val metadata: MutableMap<String, Any> = manifestObject.get("metadata") as MutableMap<String, Any>
                log.info("Uploaded config YAML object")

                for ((k, v) in metadata) {
                    metadata.put(k, configmapName)
                }

                finalManifest = manifestYaml.dump(manifestObject)
            } catch (e: Exception) {
                log.info("Error during parsing the configmap.yaml: $e")
            }
        }

        File(manifestFileName).bufferedWriter().use { out -> out.write(finalManifest) }

        log.info(finalManifest)

        log.info("Reading config template file: $templateFilePath")

        if (!templateFile.exists())
            throw BlueprintProcessorException("config template file $templateFilePath does not exists")

        val tempMainPath: File = createTempDir("config-template-", "")
        val tempConfigTemplatePath: File = createTempDir("conftemplate-", "", tempMainPath)
        log.info("Decompressing profile to $tempConfigTemplatePath")

        val decompressedProfile2: File = BlueprintArchiveUtils.deCompress(
                templateFilePath.toFile(),
                "$tempConfigTemplatePath", ArchiveType.TarGz
        )

        log.info("$templateFilePath decompression completed")

        // Here we update configmap.yaml file

        log.info("Modification of configmap.yaml file ")
        val manifestFileName2 = destPath.toString().plus(File.separator).plus(typOfVfmodule).plus(File.separator).plus("templates").plus(File.separator).plus("configmap.yaml")
        val destOverrideFile = tempConfigTemplatePath.toString().plus(File.separator).plus(typOfVfmodule).plus(File.separator).plus("templates").plus(File.separator).plus("configmap.yaml")
        log.info("destination override file $destOverrideFile")

        File(manifestFileName2).copyTo(File(destOverrideFile), true)

        if (!BlueprintArchiveUtils.compress(
                        decompressedProfile2, templateFilePath.toFile(),
                        ArchiveType.TarGz
                )
        ) {
            throw BlueprintProcessorException("Profile compression has failed")
        }

        log.info("$templateFilePath compression completed")

        return ""
    }

    inner class K8sInstanceApi(
            val username: String,
            val password: String,
            val baseUrl: String,
            val definition: String,
            val definitionVersion: String
    ) {
        private val service: UploadConfigTemplateRestClientService // BasicAuthRestClientService

        init {
            var mapOfHeaders = hashMapOf<String, String>()
            mapOfHeaders.put("Accept", "application/json")
            mapOfHeaders.put("Content-Type", "application/json")
            mapOfHeaders.put("cache-control", " no-cache")
            mapOfHeaders.put("Accept", "application/json")
            var basicAuthRestClientProperties: BasicAuthRestClientProperties = BasicAuthRestClientProperties()
            basicAuthRestClientProperties.username = username
            basicAuthRestClientProperties.password = password
            basicAuthRestClientProperties.url = "$baseUrl/v1/instance"
            basicAuthRestClientProperties.additionalHeaders = mapOfHeaders

            this.service = UploadConfigTemplateRestClientService(basicAuthRestClientProperties)
        }

        fun getInstanceDetails(instanceId: String): String {
            log.info("Executing K8sInstanceApi.getInstanceDetails")
            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.exchangeResource(HttpMethod.GET.name, "/$instanceId", "")
                print(result)
                if (result.status >= 200 && result.status < 300) {
                    log.info("K8s instance details retrieved, processing it for configmap details")
                    log.info("response body -> " + result.body.toString())
                    val cmName: String = processInstanceResponse(result.body)
                    return cmName
                } else
                    return ""
            } catch (e: Exception) {
                log.info("Caught exception trying to get k8s instance details")
                throw BlueprintProcessorException("${e.message}")
            }
        }

        fun processInstanceResponse(response: String): String {

            log.info("K8s instance details retrieved, processing it for configmap details")

            val gson = Gson()

            val startInd = response.indexOf('[')
            val endInd = response.indexOf(']')

            val subStr = response.substring(startInd, endInd + 1)

            val resourceType = object : TypeToken<Array<K8sResources>>() {}.type

            var resources: Array<K8sResources> = gson.fromJson(subStr, resourceType)

            for (resource in resources) {

                if (resource.GVK?.Kind == "ConfigMap") {

                    return resource.Name
                }
            }
            return ""
        }
    }

    inner class K8sConfigTemplateApi(
            val username: String,
            val password: String,
            val baseUrl: String,
            val definition: String,
            val definitionVersion: String,
            val configTemplateName: String
    ) {
        private val service: UploadConfigTemplateRestClientService // BasicAuthRestClientService

        init {
            var mapOfHeaders = hashMapOf<String, String>()
            mapOfHeaders.put("Accept", "application/json")
            mapOfHeaders.put("Content-Type", "application/json")
            mapOfHeaders.put("cache-control", " no-cache")
            mapOfHeaders.put("Accept", "application/json")
            var basicAuthRestClientProperties: BasicAuthRestClientProperties = BasicAuthRestClientProperties()
            basicAuthRestClientProperties.username = username
            basicAuthRestClientProperties.password = password
            basicAuthRestClientProperties.url = "$baseUrl/v1/rb/definition/$definition/$definitionVersion"
            basicAuthRestClientProperties.additionalHeaders = mapOfHeaders

            this.service = UploadConfigTemplateRestClientService(basicAuthRestClientProperties)
        }

        fun hasDefinition(): Boolean {
            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.exchangeResource(HttpMethod.GET.name, "", "")
                print(result)
                return result.status >= 200 && result.status < 300
            } catch (e: Exception) {
                log.info("Caught exception trying to get k8s config template  definition")
                throw BlueprintProcessorException("${e.message}")
            }
        }

        fun hasConfigTemplate(profile: K8sConfigTemplate): Boolean {
            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.exchangeResource(HttpMethod.GET.name, "/config-template/${profile.templateName}", "")
                print(result)
                if (result.status >= 200 && result.status < 300) {
                    log.info("ConfigTemplate already exists")
                    return true
                } else
                    return false
            } catch (e: Exception) {
                log.info("Caught exception trying to get k8s config trmplate  definition")
                throw BlueprintProcessorException("${e.message}")
            }
        }

        fun createOrUpdateConfig(configJson: K8sConfigPayloadJson, profileName: String) {
            val objectMapper = ObjectMapper()

            val configJsonString: String = objectMapper.writeValueAsString(configJson)

            log.info("payload generated -> " + configJsonString)

            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.exchangeResource(
                        HttpMethod.POST.name,
                        "/profile/$profileName/config", configJsonString
                )
                if (result.status < 200 || result.status >= 300) {
                    throw Exception(result.body)
                }
            } catch (e: Exception) {
                log.info("Caught exception trying to create or update configuration ")
                throw BlueprintProcessorException("${e.message}")
            }
        }

        fun createConfigTemplate(profile: K8sConfigTemplate) {
            val objectMapper = ObjectMapper()
            val profileJsonString: String = objectMapper.writeValueAsString(profile)
            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.exchangeResource(
                        HttpMethod.POST.name,
                        "/config-template",
                        profileJsonString
                )

                if (result.status >= 200 && result.status < 300) {
                    log.info("Config template json info uploaded correctly")
                } else if (result.status < 200 || result.status >= 300) {
                    log.info("Config template already exists")
                }
            } catch (e: Exception) {
                log.info("Caught exception trying to create k8s config template ${profile.templateName}  - updated")
            }
        }

        fun uploadConfigTemplateContent(profile: K8sConfigTemplate, filePath: Path) {
            try {
                val result: BlueprintWebClientService.WebClientResponse<String> = service.uploadBinaryFile(
                        "/config-template/${profile.templateName}/content",
                        filePath
                )
                if (result.status < 200 || result.status >= 300) {
                    throw Exception(result.body)
                }
            } catch (e: Exception) {
                log.info("Caught exception trying to upload k8s config template ${profile.templateName}")
                throw BlueprintProcessorException("${e.message}")
            }
        }
    }
}

class UploadConfigTemplateRestClientService(
        private val restClientProperties: BasicAuthRestClientProperties
) : BlueprintWebClientService {

    override fun defaultHeaders(): Map<String, String> {

        val encodedCredentials = setBasicAuth(
                restClientProperties.username,
                restClientProperties.password
        )
        return mapOf(
                HttpHeaders.CONTENT_TYPE to MediaType.APPLICATION_JSON_VALUE,
                HttpHeaders.ACCEPT to MediaType.APPLICATION_JSON_VALUE,
                HttpHeaders.AUTHORIZATION to "Basic $encodedCredentials"
        )
    }

    override fun host(uri: String): String {
        return restClientProperties.url + uri
    }

    override fun convertToBasicHeaders(headers: Map<String, String>):
            Array<BasicHeader> {
        val customHeaders: MutableMap<String, String> = headers.toMutableMap()
        // inject additionalHeaders
        customHeaders.putAll(verifyAdditionalHeaders(restClientProperties))

        if (!headers.containsKey(HttpHeaders.AUTHORIZATION)) {
            val encodedCredentials = setBasicAuth(
                    restClientProperties.username,
                    restClientProperties.password
            )
            customHeaders[HttpHeaders.AUTHORIZATION] =
                    "Basic $encodedCredentials"
        }
        return super.convertToBasicHeaders(customHeaders)
    }

    private fun setBasicAuth(username: String, password: String): String {
        val credentialsString = "$username:$password"
        return Base64.getEncoder().encodeToString(
                credentialsString.toByteArray(Charset.defaultCharset())
        )
    }

    @Throws(IOException::class, ClientProtocolException::class)
    private fun performHttpCall(httpUriRequest: HttpUriRequest): BlueprintWebClientService.WebClientResponse<String> {
        val httpResponse = httpClient().execute(httpUriRequest)
        val statusCode = httpResponse.statusLine.statusCode
        httpResponse.entity.content.use {
            val body = IOUtils.toString(it, Charset.defaultCharset())
            return BlueprintWebClientService.WebClientResponse(statusCode, body)
        }
    }

    fun uploadBinaryFile(path: String, filePath: Path): BlueprintWebClientService.WebClientResponse<String> {
        val convertedHeaders: Array<BasicHeader> = convertToBasicHeaders(defaultHeaders())
        val httpPost = HttpPost(host(path))
        val entity = EntityBuilder.create().setBinary(Files.readAllBytes(filePath)).build()
        httpPost.setEntity(entity)
        RestLoggerService.httpInvoking(convertedHeaders)
        httpPost.setHeaders(convertedHeaders)
        return performHttpCall(httpPost)
    }
}

class K8sConfigTemplate {
    @get:JsonProperty("template-name")
    var templateName: String? = null

    @get:JsonProperty("description")
    var description: String? = null

    @get:JsonProperty("ChartName")
    var ChartName: String? = null

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        return true
    }

    override fun hashCode(): Int {
        return javaClass.hashCode()
    }
}

class K8sConfigPayloadJson {
    @get:JsonProperty("template-name")
    var templateName: String? = null

    @get:JsonProperty("config-name")
    var configName: String? = null

    @get:JsonProperty("values")
    var values: Values = Values()

    override fun toString(): String {
        return "$templateName:$configName:$values"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        return true
    }

    override fun hashCode(): Int {
        return javaClass.hashCode()
    }
}

class Values {
    @get:JsonProperty("namespace")
    var namespace = "default"

    @get:JsonProperty("topic")
    var topic = Topic()

    override fun toString(): String {
        return "$namespace:$topic"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        return true
    }

    override fun hashCode(): Int {
        return javaClass.hashCode()
    }
}

class Topic {
    @get:JsonProperty("ves")
    var ves: String? = null

    @get:JsonProperty("cells")
    var cells: String? = null

    @get:JsonProperty("ues")
    var ues: String? = null

    override fun toString(): String {
        return "$ves:$cells:$ues"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        return true
    }

    override fun hashCode(): Int {
        return javaClass.hashCode()
    }
}

class K8sResources {
    var GVK: GVK? = null
    lateinit var Name: String
}

class GVK {
    var Group: String? = null
    var Version: String? = null
    var Kind: String? = null
}
