module Paginatable
  extend ActiveSupport::Concern

  MAX_PER_PAGE = 50

  private

  # Returns [records, meta]. Pass total: when relation.count would not be a number (GROUP BY returns a Hash).
  def paginate(relation, default_per_page:, total: nil)
    page = pagination_param(:page, 1)
    per_page = pagination_param(:per_page, default_per_page)
    raise_invalid_pagination unless page >= 1 && per_page.between?(1, MAX_PER_PAGE)

    total ||= relation.unscope(:order).count
    offset = (page - 1) * per_page
    # Skipping the query past the last page also avoids a bigint overflow for a huge page number.
    records = offset >= total ? relation.none : relation.offset(offset).limit(per_page)
    total_pages = [ (total + per_page - 1) / per_page, 1 ].max

    [ records, { page: page, per_page: per_page, total: total, total_pages: total_pages } ]
  end

  # An Integer or a string of digits only, so "2.5", "-1" or "12junk" are rejected instead of truncated by to_i.
  def pagination_param(name, default)
    value = params[name]
    return default if value.nil?
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(String) && value.match?(/\A\d+\z/)

    raise_invalid_pagination
  end

  def raise_invalid_pagination
    raise ApplicationController::InvalidParameter, "Invalid pagination parameters"
  end
end
