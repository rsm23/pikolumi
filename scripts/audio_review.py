"""Keep native-approved recordings bound to their exact reviewed bytes."""
import hashlib


def protected_record(record, path, text):
    review = record.get('nativeReview', {})
    if review.get('decision') != 'correct':
        return None
    sha = hashlib.sha256(path.read_bytes()).hexdigest()
    if record.get('sha256') != sha or review.get('reviewedSha256') != sha or record.get('text') != text:
        raise ValueError(f'Approved recording changed; review required: {path.name}')
    return dict(record)
