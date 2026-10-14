import inspect

from app.cron import jobs


def test_global_archive_runs_before_prices_and_pushes():
    src = inspect.getsource(jobs.daily_close_job)
    archive = src.index("archive_daily_scores(latest)")
    prices = src.index("recompute_all_prices()")
    pushes = src.index("_send_results_pushes(latest)")
    assert archive < prices < pushes
