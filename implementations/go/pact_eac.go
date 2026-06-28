package main

// PACT v0.2 expressed as Everything-as-Code in Go.
// Business values are loaded from ../../config.yml by the host application.

type SemanticTypeName string
type SemanticOperatorName string
type SemanticFieldPath string
type SemanticEvidence string
type SemanticCheckIdentifier string
type SemanticValidationResult bool

type SemanticValue any
type SemanticContext map[string]map[string]SemanticValue

type SemanticPredicate func(SemanticValue, SemanticValue) SemanticValidationResult
type SemanticValidation func(SemanticValue) SemanticValidationResult

type ArithmeticExpression struct{ Add []SemanticFieldPath `yaml:"add"`; Sub []SemanticFieldPath `yaml:"sub"` }
type PolicyRule struct { AllOf []PolicyRule `yaml:"all_of"`; AnyOf []PolicyRule `yaml:"any_of"`; Not *PolicyRule `yaml:"not"`; Field SemanticFieldPath `yaml:"field"`; Expr *ArithmeticExpression `yaml:"expr"`; Operator SemanticOperatorName `yaml:"op"`; Value SemanticValue `yaml:"value"` }
type PolicyCheck struct { CheckIdentifier SemanticCheckIdentifier `yaml:"check_id"`; Rule PolicyRule `yaml:"rule"` }
type Mandate struct { MandateIdentifier string `yaml:"mandate_id"`; PolicyVersion string `yaml:"pdpp_version"`; PrincipalIdentifier string `yaml:"principal_id"`; AgentIdentifier string `yaml:"agent_id"`; IssuedAt string `yaml:"issued_at"`; Checks []PolicyCheck `yaml:"checks"` }
type TransactionIntent map[string]SemanticValue
type PolicyInputs map[string]SemanticValue
type PolicyEvaluationCheck struct { CheckIdentifier SemanticCheckIdentifier `json:"check_id"`; Result string `json:"result"`; EvidenceReference SemanticEvidence `json:"evidence_ref"` }

func validateTypeIsInteger(value SemanticValue) SemanticValidationResult { _, valueIsInteger := value.(int); return SemanticValidationResult(valueIsInteger) }
func validateValueIsAtLeastMinimum(minimum SemanticValue) SemanticValidation { return func(value SemanticValue) SemanticValidationResult { return SemanticValidationResult(value.(int) >= minimum.(int)) } }
func validateValueIsAtMostMaximum(maximum SemanticValue) SemanticValidation { return func(value SemanticValue) SemanticValidationResult { return SemanticValidationResult(value.(int) <= maximum.(int)) } }
func composeAllValidationsMustPass(validations ...SemanticValidation) SemanticValidation { return func(value SemanticValue) SemanticValidationResult { for _, validateCurrentRule := range validations { if !validateCurrentRule(value) { return false } }; return true } }
func validateIntegerRange(minimum SemanticValue, maximum SemanticValue) SemanticValidation { return composeAllValidationsMustPass(validateTypeIsInteger, validateValueIsAtLeastMinimum(minimum), validateValueIsAtMostMaximum(maximum)) }

func compareValuesAreEqual(left SemanticValue, right SemanticValue) SemanticValidationResult { return SemanticValidationResult(left == right) }
func compareLeftValueIsLessThanOrEqualToRightValue(left SemanticValue, right SemanticValue) SemanticValidationResult { return SemanticValidationResult(left.(int) <= right.(int)) }
func compareCollectionContainsValue(value SemanticValue, collection SemanticValue) SemanticValidationResult { for _, candidate := range collection.([]SemanticValue) { if candidate == value { return true } }; return false }

func resolveFieldPathFromSemanticContext(context SemanticContext, path SemanticFieldPath) SemanticValue { namespace, key := splitFieldPathIntoNamespaceAndKey(path); return context[namespace][key] }
func splitFieldPathIntoNamespaceAndKey(path SemanticFieldPath) (string, string) { pathText := string(path); for index, character := range pathText { if character == '.' { return pathText[:index], pathText[index+1:] } }; return pathText, "" }
func addResolvedFieldsFromSemanticContext(context SemanticContext, fields []SemanticFieldPath) SemanticValue { total := 0; for _, field := range fields { total += resolveFieldPathFromSemanticContext(context, field).(int) }; return total }
func evaluateArithmeticExpression(context SemanticContext, expression ArithmeticExpression) SemanticValue { if len(expression.Add) > 0 { return addResolvedFieldsFromSemanticContext(context, expression.Add) }; return nil }
func chooseSemanticPredicate(operator SemanticOperatorName) SemanticPredicate { if operator == "eq" { return compareValuesAreEqual }; if operator == "lte" { return compareLeftValueIsLessThanOrEqualToRightValue }; if operator == "in" { return compareCollectionContainsValue }; return compareValuesAreEqual }
func evaluatePolicyRuleAgainstSemanticContext(context SemanticContext, rule PolicyRule) (SemanticValidationResult, SemanticEvidence) { if len(rule.AllOf) > 0 { for _, child := range rule.AllOf { passed, _ := evaluatePolicyRuleAgainstSemanticContext(context, child); if !passed { return false, "all_of child failed" } }; return true, "all_of children passed" }; actual := SemanticValue(nil); if rule.Expr != nil { actual = evaluateArithmeticExpression(context, *rule.Expr) } else { actual = resolveFieldPathFromSemanticContext(context, rule.Field) }; return chooseSemanticPredicate(rule.Operator)(actual, rule.Value), SemanticEvidence("semantic rule evaluated") }
func evaluateMandateAgainstTransactionAndInputs(mandate Mandate, transaction TransactionIntent, inputs PolicyInputs) []PolicyEvaluationCheck { context := SemanticContext{"transaction": map[string]SemanticValue(transaction), "inputs": map[string]SemanticValue(inputs)}; checks := []PolicyEvaluationCheck{}; for _, check := range mandate.Checks { passed, evidence := evaluatePolicyRuleAgainstSemanticContext(context, check.Rule); result := "FAIL"; if passed { result = "PASS" }; checks = append(checks, PolicyEvaluationCheck{check.CheckIdentifier, result, evidence}) }; return checks }
