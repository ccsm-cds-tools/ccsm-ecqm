library C_Mgmt_TimeToColposcopy version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include SupplementalDataElementsFHIR4 version '2.0.000' called SDE
include CQMCommon version '0.1.0' called Global
include QICoreElements version '4.1.0' called QICore
include HospiceQICore4 version '2.0.000' called Hospice
//include PalliativeCareFHIR version '0.6.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.0' called TLSL

codesystem "ObservationCategoryCodes": 'http://terminology.hl7.org/CodeSystem/observation-category'

valueset "Congenital or Acquired Absence of Cervix": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.111.12.1016'
valueset "Home Healthcare Services": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1016'
valueset "HPV Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.110.12.1059'
valueset "Hysterectomy with No Residual Cervix": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.12.1014'
valueset "Office Visit": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1001'
valueset "Online Assessments": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1089'
valueset "Pap Test": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.108.12.1017'
valueset "Preventive Care Services - Established Office Visit, 18 and Up": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1025'
valueset "Preventive Care Services-Initial Office Visit, 18 and Up": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1023'
valueset "Telephone Visits": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.101.12.1080'

valueset "HPV Positive": 'http://cts.nlm.nih.gov/fhir/ValueSet/test' //placeholder for HPV positive codes "Positive", "hrHPV 16 positive", "hrHPV 18 positive"
valueset "Abnormal Cytology Value Set": 'http://cts.nlm.nih.gov/fhir/ValueSet/test' //placeholder for abnormal cytology codes "ASCUS", "LSIL", "NILM"

code "laboratory": 'laboratory' from "ObservationCategoryCodes" display 'Laboratory'

parameter "Measurement Period" Interval<DateTime>
  default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

/*define "SDE Ethnicity":
  SDE."SDE Ethnicity"
define "SDE Payer":
  SDE."SDE Payer"
define "SDE Race":
  SDE."SDE Race"
define "SDE Sex":
  SDE."SDE Sex"*/

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[25, 65]
    and Patient.gender = 'female'
    and TLSL.FemaleorTransgenderMale
    and
      (exists "Abnormal Cytology"
      or exists "Abnormal HrHPV")

define "Abnormal HrHPV":
  ManagementLibrary.SortedHpvReports HrHPV
  where HrHPV.date in Interval[start of "Measurement Period" - 6 months, end of "Measurement Period" - 6 months)
  and HrHPV.riskTableInput in {'HPV16-, HPV18+', 'HPV16+'}

define "Abnormal Cytology":
  ManagementLibrary.SortedCytologyReports Cytology
  where Cytology.date in Interval[start of "Measurement Period" - 6 months, end of "Measurement Period" - 6 months)
  and Cytology.riskTableInput in {'ASC-H','AGC','HSIL+'}

define "Normal Cytology":
  ManagementLibrary.SortedCytologyReports Cytology
  where Cytology.date in Interval[start of "Measurement Period" - 6 months, end of "Measurement Period" - 6 months)
  and Cytology.riskTableInput = 'NILM'

define "Normal HrHPV":
  ManagementLibrary.SortedCytologyReports Cytology
  where Cytology.date in Interval[start of "Measurement Period" - 6 months, end of "Measurement Period" - 6 months)
  and Cytology.riskTableInput = 'HPV-negative'

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice"
  or Last("Normal Cytology").date > Last("Abnormal Cytology").date
  or Last("Normal HrHPV").date > Last("Abnormal HrHPV").date
  //or PalliativeCare."Palliative Care in the Measurement Period"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  or exists "Absence of Cervix"

define "Numerator":
  (exists Dash.ColposcopyProcedures C
    where Common.ProcedureDate(C) 6 months or less after "Last Abnormal Cervical Cancer Screening Result Date")
  or
  (exists QICore."ServiceRequest" SR
    where SR.code ~ null //  TODO: Colposcopy procedure code
    and SR.authoredOn 30 days or less after "Last Abnormal Cervical Cancer Screening Result Date")

define "Last Abnormal Cervical Cancer Screening Result Date":
  Last(("Abnormal Cytology" union "Abnormal HrHPV") tests //Need most recent abnormal results
  return tests sort by date).date

define "Absence of Cervix":
  (
    QICore.ProcedureCompleted NoCervixProcedure
      where NoCervixProcedure.code in "Hysterectomy with No Residual Cervix"
        and NoCervixProcedure.performed.toInterval() ends on or before end of "Measurement Period"
  )
    union (
      QICore.Condition NoCervixDiagnosis
        where NoCervixDiagnosis.code in "Congenital or Acquired Absence of Cervix"
          and NoCervixDiagnosis.prevalenceInterval() starts on or before end of "Measurement Period"
    )
