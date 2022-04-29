# Cervical Cancer Screening and Management eCQMs

## Draft Content
The content in this CCSM eCQM repository is in a DRAFT state and is not for general use. This repository contains measure definitions which are under *active development*. The eCQMs have not been tested in a clinical environment and should be considered a *work-in-progress*. Per the [Apache-2.0 License under which the CCSM eCQMs are released](#licenses), *no warranty is made* and *no liability is assumed*.

## Content Index

The following table provides an index to the currently available library content in this implementation guide:

### Shared Libraries

|Library|Version|Status|
|----|----|----|


### Measure Libraries

|Library|Version|Status|
|----|----|----|


### Measures

|Measure|Description|
|----|----|


## Repository Structure
It is setup like any HL7 FHIR IG project but also includes the CQL files and test data which means the file structure will be as follows:

```
   |-- _genonce.bat
   |-- _genonce.sh
   |-- _refresh.bat
   |-- _refresh.sh
   |-- _updatePublisher.bat
   |-- _updatePublisher.sh
   |-- _updateCQFTooling.bat
   |-- _updateCQFTooling.sh
   |-- ig.ini
   |-- bundles
       |-- mat
           |--<mat export bundles>
       |-- measure
           |--EXM124
   |-- input
       |-- cql
           |-- 
       |-- resources
           |-- library
           |-- measure
       |-- tests
           |-- measure
       |-- vocabulary
           |-- valueset
```

## Refresh IG Processing

The CQF Tooling provides support for refreshing measure and library resources based on
the content of the CQL libraries, as well as packaging the measures as artifacts that
include dependencies and test cases.

To run this tooling, make sure it is available locally using the _updateCQFTooling script,
then run the _refresh script. This script should be run whenever CQL content changes,
and prior to the publishing process.

## Extracting MAT Packages

The CQF Tooling provides support for extracting a MAT exported package into the
directories of this repository so that the measure is included in the published
implementation guide. To do this, place the MAT export files (unzipped) in a
directory in the `bundles\mat` directory, and then run the following tooling
command:

```
[tooling-jar] -ExtractMatBundle bundles\mat\[bundle-directory]\[bundle-file]
```

For example:

```
input-cache\tooling-1.3.1-SNAPSHOT-jar-with-dependencies.jar -ExtractMATBundle bundles\mat\CLONE124_v6_03-Artifacts\measure-json-bundle.json
```

Then run the `_refresh` command to refresh the implementation guide content with
the new content, and then run `_genonce` to publish the implementation guide.

## Licenses

(C) 2021 The MITRE Corporation. All Rights Reserved. Approved for Public Release: 21-1556. Distribution Unlimited.

Unless otherwise noted, the CCSM eCQMs are available under an [Apache 2.0 license](./LICENSE). It was produced by the MITRE Corporation for the Division of Cancer Prevention and Control, Centers for Disease Control and Prevention in accordance with the Statement of Work, contract number 75FCMC18D0047, task order number 75D30120F09743.

Any LOINC (http://loinc.org) content is copyright &copy; 1995+, Regenstrief Institute, Inc. and the Logical Observation Identifiers Names and Codes (LOINC) Committee and is available at no cost under the license at http://loinc.org/license. LOINC<sup>&reg;</sup> is a registered United States trademark of Regenstrief Institute, Inc.

The CCSM eCQMs and test cases make reference to several clinical terminology systems and value sets available through the [Unified Medical Language System (UMLS)](https://www.nlm.nih.gov/research/umls/index.html) and the [Value Set Authority Center (VSAC)](https://vsac.nlm.nih.gov/), both operated by the United States National Library of Medicine. These resources require an account and license through [UMLS Terminology Services (UTS)](https://uts.nlm.nih.gov/uts/).