library C_Mgmt_TimeToColposcopy version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CCSMCommonFunctions version '1.0.0' called Common
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include HPVVaccination_SDE version '0.0.1' called HPVVaccination_SDE

codesystem "SNOMED-CT": 'http://snomed.info/sct'

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'
valueset "Referral for Colposcopy": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.276'
valueset "Referral for Treatment": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113762.1.4.1032.277'

code "SCC": '1162767002' from "SNOMED-CT" display 'Squamous cell carcinoma'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[24, 65]
    and TLSL.FemaleorTransgenderMale
    and
      (exists "Abnormal Cytology"
      or exists "Abnormal HrHPV")

define "Abnormal HrHPV":
  ManagementLibrary.SortedHpvReports HrHPV
  where HrHPV.date in Interval[start of "Measurement Period" - 6 months, start of "Measurement Period" + 6 months)
    and HrHPV.riskTableInput in {'HPV16-, HPV18+', 'HPV16+'}

define "Abnormal Cytology":
  (ManagementLibrary.SortedCytologyReports Cytology
    where Cytology.date in Interval[start of "Measurement Period" - 6 months, start of "Measurement Period" + 6 months)
      and Cytology.riskTableInput in {'ASC-H','AGC','HSIL+'})
  union
  ([DiagnosticReport: "SCC"] DR
    where DR.effective overlaps Interval[start of "Measurement Period" - 6 months, start of "Measurement Period" + 6 months)
      and DR.code ~ "SCC")

define "Normal Cytology":
  ManagementLibrary.SortedCytologyReports Cytology
  where Cytology.date in Interval[start of "Measurement Period" - 6 months, start of "Measurement Period" + 6 months)
  and Cytology.riskTableInput = 'NILM'

define "Normal HrHPV":
  ManagementLibrary.SortedCytologyReports Cytology
  where Cytology.date in Interval[start of "Measurement Period" - 6 months, start of "Measurement Period" + 6 months)
  and Cytology.riskTableInput = 'HPV-negative'

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or Last("Normal Cytology").date > Last("Abnormal Cytology").date
  or Last("Normal HrHPV").date > Last("Abnormal HrHPV").date
  or PalliativeCare."Palliative Care in the Measurement Period"
  or ManagementLibrary."HasCervicalCancerDiagnoses"
  or "Absence of Cervix"

define "Numerator":
  exists (Dash.ColposcopyProcedures C
    where Common.ProcedureDate(C) 6 months or less after "Last Abnormal Cervical Cancer Screening Result Date")
  or
  exists (ManagementLibrary."SortedBiopsyReports" Biopsy
    where Biopsy.date 6 months or less after "Last Abnormal Cervical Cancer Screening Result Date")
  or
  exists (ManagementLibrary."CervicalPrecancerTreatments" AblationOrExcision
    where Common.ProcedureDate(AblationOrExcision) 6 months or less after "Last Abnormal Cervical Cancer Screening Result Date")
  or
  exists ("Colposcopy or Treatment Referral" R
    where R.authoredOn 30 days or less after "Last Abnormal Cervical Cancer Screening Result Date")

define "Colposcopy or Treatment Referral":
  ([ServiceRequest: "Referral for Colposcopy"] ColpoReferral
    where ColpoReferral.status in { 'draft', 'active', 'on-hold', 'completed' }
    and ColpoReferral.doNotPerform is not true)
  union
  ([ServiceRequest: "Referral for Treatment"] TreatmentReferral
    where TreatmentReferral.status in { 'draft', 'active', 'on-hold', 'completed' }
    and TreatmentReferral.doNotPerform is not true)

define "Last Abnormal Cervical Cancer Screening Result Date":
  Last(("Abnormal Cytology" union "Abnormal HrHPV") tests
  return tests sort by date).date

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

define "SDE HPV Vaccination Status":
  HPVVaccination_SDE."HPV Vaccinated"
