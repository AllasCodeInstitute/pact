import gleam/list

pub type SemanticValue { SemanticInteger(Int) SemanticText(String) SemanticTextCollection(List(String)) SemanticMissing }
pub type SemanticValidationResult { SemanticValidationPassed SemanticValidationFailed }
pub type SemanticFieldPath { SemanticFieldPath(String) }
pub type SemanticOperatorName { SemanticOperatorName(String) }
pub type SemanticEvidence { SemanticEvidence(String) }
pub type SemanticValidation = fn(SemanticValue) -> SemanticValidationResult

pub fn validate_type_is_integer(value: SemanticValue) -> SemanticValidationResult { case value { SemanticInteger(_) -> SemanticValidationPassed _ -> SemanticValidationFailed } }
pub fn validate_value_is_at_least_minimum(minimum: SemanticValue) -> SemanticValidation { fn(value) { case #(value, minimum) { #(SemanticInteger(actual), SemanticInteger(limit)) if actual >= limit -> SemanticValidationPassed _ -> SemanticValidationFailed } } }
pub fn validate_value_is_at_most_maximum(maximum: SemanticValue) -> SemanticValidation { fn(value) { case #(value, maximum) { #(SemanticInteger(actual), SemanticInteger(limit)) if actual <= limit -> SemanticValidationPassed _ -> SemanticValidationFailed } } }
pub fn compose_all_validations_must_pass(validations: List(SemanticValidation)) -> SemanticValidation { fn(value) { case list.all(validations, fn(validate_current_rule) { validate_current_rule(value) == SemanticValidationPassed }) { True -> SemanticValidationPassed False -> SemanticValidationFailed } } }
pub fn validate_integer_range(minimum: SemanticValue, maximum: SemanticValue) -> SemanticValidation { compose_all_validations_must_pass([validate_type_is_integer, validate_value_is_at_least_minimum(minimum), validate_value_is_at_most_maximum(maximum)]) }

pub type ArithmeticExpression { ArithmeticExpression(add: List(SemanticFieldPath), sub: List(SemanticFieldPath)) }
pub type PolicyRule { PolicyRule(all_of: List(PolicyRule), field: Option(SemanticFieldPath), expression: Option(ArithmeticExpression), operator: SemanticOperatorName, value: SemanticValue) }
pub type PolicyCheck { PolicyCheck(check_identifier: String, rule: PolicyRule) }
pub type Mandate { Mandate(checks: List(PolicyCheck)) }
pub type PolicyEvaluationCheck { PolicyEvaluationCheck(check_identifier: String, result: String, evidence_reference: SemanticEvidence) }

pub fn compare_values_are_equal(left: SemanticValue, right: SemanticValue) -> SemanticValidationResult { case left == right { True -> SemanticValidationPassed False -> SemanticValidationFailed } }
pub fn compare_left_value_is_less_than_or_equal_to_right_value(left: SemanticValue, right: SemanticValue) -> SemanticValidationResult { case #(left, right) { #(SemanticInteger(actual), SemanticInteger(limit)) if actual <= limit -> SemanticValidationPassed _ -> SemanticValidationFailed } }
pub fn compare_collection_contains_value(value: SemanticValue, collection: SemanticValue) -> SemanticValidationResult { case #(value, collection) { #(SemanticText(actual), SemanticTextCollection(allowed)) -> case list.contains(allowed, actual) { True -> SemanticValidationPassed False -> SemanticValidationFailed } _ -> SemanticValidationFailed } }
