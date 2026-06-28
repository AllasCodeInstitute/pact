use std::collections::BTreeMap;

pub struct SemanticTypeName(pub String);
pub struct SemanticOperatorName(pub String);
pub struct SemanticFieldPath(pub String);
pub struct SemanticEvidence(pub String);
pub struct SemanticCheckIdentifier(pub String);
pub struct SemanticValidationResult(pub bool);

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum SemanticValue { Integer(i64), Text(String), TextCollection(Vec<String>), Missing }
pub type SemanticNamespace = BTreeMap<String, SemanticValue>;
pub type SemanticContext = BTreeMap<String, SemanticNamespace>;
pub type SemanticValidation = Box<dyn Fn(&SemanticValue) -> SemanticValidationResult>;

pub fn validate_type_is_integer(value: &SemanticValue) -> SemanticValidationResult { SemanticValidationResult(matches!(value, SemanticValue::Integer(_))) }
pub fn validate_value_is_at_least_minimum(minimum: SemanticValue) -> SemanticValidation { Box::new(move |value| match (value, &minimum) { (SemanticValue::Integer(actual), SemanticValue::Integer(limit)) => SemanticValidationResult(actual >= limit), _ => SemanticValidationResult(false) }) }
pub fn validate_value_is_at_most_maximum(maximum: SemanticValue) -> SemanticValidation { Box::new(move |value| match (value, &maximum) { (SemanticValue::Integer(actual), SemanticValue::Integer(limit)) => SemanticValidationResult(actual <= limit), _ => SemanticValidationResult(false) }) }
pub fn compose_all_validations_must_pass(validations: Vec<SemanticValidation>) -> SemanticValidation { Box::new(move |value| SemanticValidationResult(validations.iter().all(|validate_current_rule| validate_current_rule(value).0))) }
pub fn validate_integer_range(minimum: SemanticValue, maximum: SemanticValue) -> SemanticValidation { compose_all_validations_must_pass(vec![Box::new(validate_type_is_integer), validate_value_is_at_least_minimum(minimum), validate_value_is_at_most_maximum(maximum)]) }

pub struct ArithmeticExpression { pub add: Vec<SemanticFieldPath>, pub sub: Vec<SemanticFieldPath> }
pub struct PolicyRule { pub all_of: Vec<PolicyRule>, pub field: Option<SemanticFieldPath>, pub expression: Option<ArithmeticExpression>, pub operator: SemanticOperatorName, pub value: SemanticValue }
pub struct PolicyCheck { pub check_identifier: SemanticCheckIdentifier, pub rule: PolicyRule }
pub struct Mandate { pub checks: Vec<PolicyCheck> }
pub struct PolicyEvaluationCheck { pub check_identifier: SemanticCheckIdentifier, pub result: String, pub evidence_reference: SemanticEvidence }

pub fn compare_values_are_equal(left: &SemanticValue, right: &SemanticValue) -> SemanticValidationResult { SemanticValidationResult(left == right) }
pub fn compare_left_value_is_less_than_or_equal_to_right_value(left: &SemanticValue, right: &SemanticValue) -> SemanticValidationResult { match (left, right) { (SemanticValue::Integer(actual), SemanticValue::Integer(limit)) => SemanticValidationResult(actual <= limit), _ => SemanticValidationResult(false) } }
pub fn compare_collection_contains_value(value: &SemanticValue, collection: &SemanticValue) -> SemanticValidationResult { match (value, collection) { (SemanticValue::Text(actual), SemanticValue::TextCollection(allowed)) => SemanticValidationResult(allowed.contains(actual)), _ => SemanticValidationResult(false) } }
pub fn resolve_field_path_from_semantic_context(context: &SemanticContext, path: &SemanticFieldPath) -> SemanticValue { let (namespace, key) = split_field_path_into_namespace_and_key(path); context.get(&namespace).and_then(|values| values.get(&key)).cloned().unwrap_or(SemanticValue::Missing) }
pub fn split_field_path_into_namespace_and_key(path: &SemanticFieldPath) -> (String, String) { let mut pieces = path.0.splitn(2, '.'); (pieces.next().unwrap_or_default().to_string(), pieces.next().unwrap_or_default().to_string()) }
pub fn add_resolved_fields_from_semantic_context(context: &SemanticContext, fields: &[SemanticFieldPath]) -> SemanticValue { SemanticValue::Integer(fields.iter().map(|field| match resolve_field_path_from_semantic_context(context, field) { SemanticValue::Integer(value) => value, _ => 0 }).sum()) }
pub fn evaluate_arithmetic_expression(context: &SemanticContext, expression: &ArithmeticExpression) -> SemanticValue { if !expression.add.is_empty() { return add_resolved_fields_from_semantic_context(context, &expression.add); } SemanticValue::Missing }
pub fn choose_semantic_predicate(operator: &SemanticOperatorName) -> fn(&SemanticValue, &SemanticValue) -> SemanticValidationResult { match operator.0.as_str() { "lte" => compare_left_value_is_less_than_or_equal_to_right_value, "in" => compare_collection_contains_value, _ => compare_values_are_equal } }
pub fn evaluate_policy_rule_against_semantic_context(context: &SemanticContext, rule: &PolicyRule) -> (SemanticValidationResult, SemanticEvidence) { if !rule.all_of.is_empty() { let passed = rule.all_of.iter().all(|child| evaluate_policy_rule_against_semantic_context(context, child).0.0); return (SemanticValidationResult(passed), SemanticEvidence("all_of children evaluated".into())); } let actual = rule.expression.as_ref().map(|expression| evaluate_arithmetic_expression(context, expression)).unwrap_or_else(|| resolve_field_path_from_semantic_context(context, rule.field.as_ref().unwrap())); (choose_semantic_predicate(&rule.operator)(&actual, &rule.value), SemanticEvidence("semantic rule evaluated".into())) }
pub fn evaluate_mandate_against_transaction_and_inputs(mandate: &Mandate, context: &SemanticContext) -> Vec<PolicyEvaluationCheck> { mandate.checks.iter().map(|check| { let (passed, evidence) = evaluate_policy_rule_against_semantic_context(context, &check.rule); PolicyEvaluationCheck { check_identifier: SemanticCheckIdentifier(check.check_identifier.0.clone()), result: if passed.0 { "PASS".into() } else { "FAIL".into() }, evidence_reference: evidence } }).collect() }
