namespace ExploreMy.Api.Common.Exceptions;

public class AuthenticationException : Exception
{
    public AuthenticationException(string message) : base(message)
    {
    }
}

public class ForbiddenException : Exception
{
    public ForbiddenException(string message) : base(message)
    {
    }
}

public class NotFoundException : Exception
{
    public NotFoundException(string message) : base(message)
    {
    }
}

public class ConflictException : Exception
{
    public ConflictException(string message) : base(message)
    {
    }
}

public class ValidationException : Exception
{
    public ValidationException(string message) : base(message)
    {
    }
}

/// <summary>
/// Marker thrown by repositories when a DB unique constraint caught a concurrent
/// duplicate insert (e.g. UNIQUE(post_id, reporter_id) on reports). Service layers
/// catch it and return the same graceful outcome as the sequential-duplicate path
/// (409/400/idempotent success) instead of a raw 500.
/// </summary>
public class ConcurrentDuplicateException : Exception
{
    public ConcurrentDuplicateException() : base("A concurrent duplicate submission was rejected by a unique constraint.")
    {
    }
}