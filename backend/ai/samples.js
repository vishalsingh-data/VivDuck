export const BINARY_SEARCH_SAMPLE = {
  id: 'binary_search',
  title: 'Binary search',
  kind: 'code',
  language: 'python',

  submission: `def binary_search(arr, target):
    lo, hi = 0, len(arr) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            lo = mid + 1
        else:
            hi = mid - 1
    return -1`,

  rubric: {
    key_points: [
      {
        id: 'kp1',
        statement: 'The input array must be sorted for binary search to work correctly.'
      },
      {
        id: 'kp2',
        statement: 'The lo and hi pointers shrink the search window on every iteration.'
      },
      {
        id: 'kp3',
        statement: 'The midpoint value is compared with the target to decide which half to search.'
      },
      {
        id: 'kp4',
        statement: 'The loop continues while lo is less than or equal to hi.'
      },
      {
        id: 'kp5',
        statement: 'The function returns -1 when the target is not found.'
      },
      {
        id: 'kp6',
        statement: 'Binary search runs in O(log n) time.'
      }
    ],

    trap: {
      question: 'Your midpoint is computed as (lo + hi) // 2. Why might writing (lo + hi) / 2 cause a problem in languages like Java or C?',
      answer: 'In fixed-width integer languages, lo + hi can overflow before division. A safer midpoint calculation is lo + (hi - lo) / 2.'
    }
  }
};
