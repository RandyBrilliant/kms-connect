"""
EXAMPLE: How to add a new criterion to the scoring system.

This file shows you exactly what changes to make in scoring.py
to add "Work Experience Quality" as a new scoring factor.

Follow these 3 steps:
"""

# ============================================================================
# STEP 1: Add a new weight constant at the top of scoring.py
# ============================================================================

# In scoring.py, update the weights section:
# 
# BEFORE:
# PROFILE_COMPLETENESS_WEIGHT: float = 0.6
# DOCUMENT_WEIGHT: float = 0.4
#
# AFTER (adjust weights so they sum to 1.0):
# PROFILE_COMPLETENESS_WEIGHT: float = 0.5  # Reduced from 0.6
# DOCUMENT_WEIGHT: float = 0.3                # Reduced from 0.4
# WORK_EXPERIENCE_WEIGHT: float = 0.2        # NEW: 20% weight for work experience


# ============================================================================
# STEP 2: Create a new ratio function (add this to scoring.py)
# ============================================================================

def work_experience_ratio(applicant_profile: Any) -> float:
    """
    Calculate ratio (0..1) based on work experience quality.
    
    Scoring logic:
    - Has at least one work experience entry: 0.5 points
    - Each complete entry (company_name + start_date + position): +0.1 per entry
    - Has overseas experience (country != 'ID'): +0.2 bonus
    - Maximum: 1.0 (100%)
    
    Returns 0.0 if no work experiences exist or if there's an error.
    """
    try:
        # Access work_experiences relation (must be prefetched/loaded)
        work_experiences = getattr(applicant_profile, "work_experiences", None)
        
        # Handle both queryset and list-like objects
        if work_experiences is None:
            return 0.0
        
        # Convert to list if it's a queryset (but prefer prefetch_related in views)
        if hasattr(work_experiences, "all"):
            work_experiences = list(work_experiences.all())
        elif not isinstance(work_experiences, (list, tuple)):
            return 0.0
        
        if len(work_experiences) == 0:
            return 0.0
        
        # Base score: has at least one entry
        score = 0.5
        
        # Count complete entries (has company_name, start_date, and position)
        complete_count = 0
        has_overseas = False
        
        for exp in work_experiences:
            company = getattr(exp, "company_name", None)
            start_date = getattr(exp, "start_date", None)
            position = getattr(exp, "position", None)
            country = getattr(exp, "country", None)
            
            # Check if entry is complete
            if _is_filled(company) and start_date is not None and _is_filled(position):
                complete_count += 1
            
            # Check for overseas experience (country code != 'ID' for Indonesia)
            if country and str(country).upper() != "ID":
                has_overseas = True
        
        # Add points for complete entries (max 0.4 points from this)
        score += min(complete_count * 0.1, 0.4)
        
        # Bonus for overseas experience
        if has_overseas:
            score += 0.2
        
        # Clamp to 0..1
        return min(max(score, 0.0), 1.0)
        
    except Exception:
        # Fail-safe: return 0 if anything goes wrong
        return 0.0


# ============================================================================
# STEP 3: Update calculate_readiness_score() to include the new criterion
# ============================================================================

# In scoring.py, update calculate_readiness_score():
#
# BEFORE:
# def calculate_readiness_score(applicant_profile: Any) -> float:
#     pc_ratio = profile_completeness_ratio(applicant_profile)
#     doc_ratio_val = document_ratio(applicant_profile)
#     
#     total = (
#         pc_ratio * PROFILE_COMPLETENESS_WEIGHT * 100.0
#         + doc_ratio_val * DOCUMENT_WEIGHT * 100.0
#     )
#     ...
#
# AFTER:
# def calculate_readiness_score(applicant_profile: Any) -> float:
#     pc_ratio = profile_completeness_ratio(applicant_profile)
#     doc_ratio_val = document_ratio(applicant_profile)
#     work_exp_ratio = work_experience_ratio(applicant_profile)  # NEW
#     
#     total = (
#         pc_ratio * PROFILE_COMPLETENESS_WEIGHT * 100.0
#         + doc_ratio_val * DOCUMENT_WEIGHT * 100.0
#         + work_exp_ratio * WORK_EXPERIENCE_WEIGHT * 100.0  # NEW
#     )
#     ...


# ============================================================================
# OPTIONAL STEP 4: Hook into WorkExperience.save() if needed
# ============================================================================

# If you want the score to update when work experiences change,
# add this to WorkExperience.save() in models.py:
#
# def save(self, *args, **kwargs):
#     super().save(*args, **kwargs)
#     
#     # Recompute applicant score when work experience changes
#     if self.applicant_profile_id:
#         from .services.scoring import recalculate_and_persist_score
#         recalculate_and_persist_score(self.applicant_profile)
#
# def delete(self, *args, **kwargs):
#     profile = self.applicant_profile if self.applicant_profile_id else None
#     super().delete(*args, **kwargs)
#     
#     if profile is not None:
#         from .services.scoring import recalculate_and_persist_score
#         recalculate_and_persist_score(profile)


# ============================================================================
# PERFORMANCE NOTE: Prefetch work_experiences in views
# ============================================================================

# To avoid N+1 queries, make sure your views prefetch work_experiences:
#
# In your view/queryset:
# queryset = ApplicantProfile.objects.select_related("user").prefetch_related("work_experiences")
#
# This ensures work_experience_ratio() doesn't trigger extra DB queries.
