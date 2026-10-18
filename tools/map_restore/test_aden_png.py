"""Numerical survey tests; never synthetic original-art or gameplay evidence."""
import unittest
import numpy as np
from aden_png import fit, world


class SurveyTests(unittest.TestCase):
    def points(self):
        matrix = np.array([[1/6, .003, 900], [-.001, 1/6, -250]])
        source = [(33400, 32800), (33440, 32800), (33440, 32840),
                  (33400, 32840), (33410, 32820), (33430, 32810)]
        return [dict(source=p, image=(matrix @ np.r_[world(p), 1]).tolist()) for p in source], matrix

    def test_measured_affine_recovers_world_units(self):
        points, matrix = self.points()
        result = fit(points)
        np.testing.assert_allclose(np.array(result['world_to_image']).reshape(2, 3), matrix, atol=1e-7)
        self.assertLess(result['max_world'], .0001)

    def test_bad_control_point_is_not_hidden_by_least_squares(self):
        points, _ = self.points()
        points[-1]['image'][0] += 8
        self.assertGreater(fit(points)['max_world'], 4)

    def test_collinear_survey_rejected(self):
        with self.assertRaises(ValueError):
            fit([dict(source=[33400+i, 32800], image=[i, 0]) for i in range(5)])


if __name__ == '__main__':
    unittest.main()
